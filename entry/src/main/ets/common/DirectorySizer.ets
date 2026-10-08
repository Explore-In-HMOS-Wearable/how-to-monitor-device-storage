/** Recursive sandbox walk over `fileIo.listFile`/`stat`: which directory grew, not just a total. */

// ListFileOptions is a top-level export of the kit, not a member of the fileIo namespace.
import { fileIo, ListFileOptions } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DirUsage } from '../model/StorageModels';

const DEFAULT_MAX_DEPTH: number = 16;

/** Mutable accumulator used while recursing; converted into the immutable DirUsage on the way out. */
class WalkTotals {
  sizeBytes: number = 0;
  fileCount: number = 0;
  errorCount: number = 0;

  /** Folds a finished child node's figures into this accumulator. */
  addNode(child: DirUsage): void {
    this.sizeBytes += child.sizeBytes;
    this.fileCount += child.fileCount;
    this.errorCount += child.errorCount;
  }
}

export class DirectorySizer {
  /** Walks `path`, listing immediate subdirectories as `children`; maxDepth 0 means own files only. */
  static async measure(path: string, displayName: string,
    maxDepth: number = DEFAULT_MAX_DEPTH): Promise<DirUsage> {
    return DirectorySizer.walk(path, displayName, maxDepth, true);
  }

  /** The recursion behind `measure`; `collectChildren` is true only for the level the UI renders. */
  private static async walk(path: string, displayName: string, maxDepth: number,
    collectChildren: boolean): Promise<DirUsage> {
    const node: DirUsage = {
      name: displayName,
      path: path,
      sizeBytes: 0,
      fileCount: 0,
      errorCount: 0,
      children: []
    };

    let entries: string[] = [];
    try {
      // Non-recursive listing, so the recursion below can attribute bytes per child.
      entries = await fileIo.listFile(path);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      // Missing is normal: a fresh install has no databaseDir until something writes.
      console.warn(`[DirectorySizer] cannot list ${path}: code=${err.code} msg=${err.message}`);
      node.errorCount = 1;
      return node;
    }

    const totals: WalkTotals = new WalkTotals();
    for (const entry of entries) {
      const childPath: string = `${path}/${entry}`;
      let isDir: boolean = false;
      let entrySize: number = 0;
      try {
        const stat: fileIo.Stat = await fileIo.stat(childPath);
        isDir = stat.isDirectory();
        entrySize = stat.size;
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        console.warn(`[DirectorySizer] cannot stat ${childPath}: code=${err.code}`);
        totals.errorCount++;
        continue;
      }

      if (isDir) {
        if (maxDepth <= 0) {
          // Depth budget spent: count it unmeasured rather than silently zero.
          totals.errorCount++;
          continue;
        }
        const child: DirUsage = await DirectorySizer.walk(childPath, entry, maxDepth - 1, false);
        if (collectChildren) {
          node.children.push(child);
        }
        totals.addNode(child);
      } else {
        // Only regular files add bytes; a directory Stat.size is its inode record.
        totals.sizeBytes += entrySize;
        totals.fileCount++;
      }
    }

    node.sizeBytes = totals.sizeBytes;
    node.fileCount = totals.fileCount;
    node.errorCount = totals.errorCount;
    // Biggest consumer first - the reason anyone opens this screen.
    node.children.sort((a: DirUsage, b: DirUsage) => b.sizeBytes - a.sizeBytes);
    return node;
  }

  /** One-shot alternative: `listFile` recurses itself, but returns a flat list with no attribution. */
  static async measureFlat(path: string): Promise<number> {
    const options: ListFileOptions = { recursion: true, listNum: 0 };
    let entries: string[] = [];
    try {
      entries = await fileIo.listFile(path, options);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.warn(`[DirectorySizer] recursive listFile failed on ${path}: code=${err.code}`);
      return 0;
    }

    let total: number = 0;
    for (const relative of entries) {
      try {
        // Paths come back relative to `path`, so they are joined again before stat().
        const stat: fileIo.Stat = await fileIo.stat(`${path}/${relative}`);
        if (!stat.isDirectory()) {
          total += stat.size;
        }
      } catch (error) {
        // Same tolerance as the walk: skip what cannot be read.
        continue;
      }
    }
    return total;
  }
}
