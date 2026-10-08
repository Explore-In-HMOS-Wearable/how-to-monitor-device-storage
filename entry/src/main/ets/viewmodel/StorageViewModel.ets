/** Folds statfs, storageStatistics and the sandbox walk into one snapshot, run concurrently. */

import { common } from '@kit.AbilityKit';
import { DeviceStorage } from '../common/DeviceStorage';
import { BundleStorage } from '../common/BundleStorage';
import { DirectorySizer } from '../common/DirectorySizer';
import { AppSpace, DeviceSpace, DirUsage, EmptyStorage, StorageSnapshot } from '../model/StorageModels';

/** One sandbox root to walk, paired with the label shown on screen. */
export interface SandboxRoot {
  name: string;
  path: string;
}

export class StorageViewModel {
  /** Lists the sandbox directories worth measuring, skipping any the context does not expose. */
  static sandboxRoots(context: common.Context): SandboxRoot[] {
    const candidates: SandboxRoot[] = [
      { name: 'files', path: context.filesDir },
      { name: 'cache', path: context.cacheDir },
      { name: 'temp', path: context.tempDir },
      { name: 'preferences', path: context.preferencesDir },
      { name: 'database', path: context.databaseDir }
    ];
    return candidates.filter((root: SandboxRoot) => root.path.length > 0);
  }

  /** Runs a full refresh; never throws - a failed source comes back as `available: false` plus a message. */
  static async refresh(context: common.Context): Promise<StorageSnapshot> {
    const startedAt: number = Date.now();
    let errorMessage: string = '';

    // Started together so they overlap, awaited separately so one failure cannot discard the other.
    const devicePromise: Promise<DeviceSpace> = DeviceStorage.read(context);
    const appPromise: Promise<AppSpace> = BundleStorage.read();

    let device: DeviceSpace = EmptyStorage.device();
    try {
      device = await devicePromise;
    } catch (error) {
      errorMessage = (error as Error).message;
      console.error(`[StorageViewModel] device storage query failed: ${errorMessage}`);
    }

    // read() resolves even without the capability, so this try only guards an unexpected throw.
    let app: AppSpace = EmptyStorage.app();
    try {
      app = await appPromise;
    } catch (error) {
      console.error(`[StorageViewModel] bundle storage query failed: ${(error as Error).message}`);
    }

    // Then the walk, one measure() per sandbox root, also concurrently.
    let roots: DirUsage[] = [];
    try {
      const walks: Promise<DirUsage>[] = StorageViewModel.sandboxRoots(context)
        .map((root: SandboxRoot) => DirectorySizer.measure(root.path, root.name));
      roots = await Promise.all(walks);
      roots.sort((a: DirUsage, b: DirUsage) => b.sizeBytes - a.sizeBytes);
    } catch (error) {
      const walkError: string = (error as Error).message;
      console.error(`[StorageViewModel] sandbox walk failed: ${walkError}`);
      if (errorMessage.length === 0) {
        errorMessage = walkError;
      }
    }

    let walkedTotalBytes: number = 0;
    for (const root of roots) {
      walkedTotalBytes += root.sizeBytes;
    }

    return {
      device: device,
      app: app,
      roots: roots,
      walkedTotalBytes: walkedTotalBytes,
      elapsedMs: Date.now() - startedAt,
      errorMessage: errorMessage
    };
  }
}
