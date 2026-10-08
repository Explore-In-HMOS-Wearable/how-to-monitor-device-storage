/** Shared models: one vocabulary for the three unrelated shapes the storage sources return. */

/** Device-level figures, produced from `statfs.getTotalSize` / `statfs.getFreeSize`. */
export interface DeviceSpace {
  /** Total bytes of the file system the queried path lives on. */
  totalBytes: number;
  /** Bytes still available to this app. */
  freeBytes: number;
  /** totalBytes - freeBytes. */
  usedBytes: number;
  /** The path that was measured; kept so the UI can show what the numbers refer to. */
  measuredPath: string;
  /** False before the first query and whenever statfs failed; `0 B free` would be a wrong claim. */
  available: boolean;
}

/** Per-application figures, produced from `storageStatistics.getCurrentBundleStats()`. */
export interface AppSpace {
  /** Installation files (the HAP itself). */
  appSize: number;
  /** Cache directories, EL1 + EL2. */
  cacheSize: number;
  /** User data, excluding install files and cache. */
  dataSize: number;
  /** appSize + cacheSize + dataSize. */
  totalSize: number;
  /** False without the SpatialStatistics capability, or before the first query; the UI then shows `--`. */
  available: boolean;
}

/** One node of the recursive sandbox walk. */
export interface DirUsage {
  /** Display name, e.g. `files`, `cache`. */
  name: string;
  /** Absolute sandbox path that was walked. */
  path: string;
  /** Sum of every regular file below this node. */
  sizeBytes: number;
  /** Number of regular files counted. */
  fileCount: number;
  /** Entries that could not be read (permissions, races); the walk continues past them. */
  errorCount: number;
  /** Immediate children, filled one level deep for display. */
  children: DirUsage[];
}

/** Everything one refresh produces. */
export interface StorageSnapshot {
  device: DeviceSpace;
  app: AppSpace;
  /** Sandbox roots that were walked (files, cache, temp, preferences, database). */
  roots: DirUsage[];
  /** Sum of every root's sizeBytes - the walk's own answer to "how much am I using". */
  walkedTotalBytes: number;
  /** Wall-clock ms the refresh took, shown in the codelab to make the I/O cost visible. */
  elapsedMs: number;
  /** Empty when the refresh was clean; otherwise the first failure, for the UI to show. */
  errorMessage: string;
}

/** Empty values so the UI has something to render before the first refresh completes. */
export class EmptyStorage {
  static device(): DeviceSpace {
    return { totalBytes: 0, freeBytes: 0, usedBytes: 0, measuredPath: '', available: false };
  }

  static app(): AppSpace {
    return { appSize: 0, cacheSize: 0, dataSize: 0, totalSize: 0, available: false };
  }

  static snapshot(): StorageSnapshot {
    return {
      device: EmptyStorage.device(),
      app: EmptyStorage.app(),
      roots: [],
      walkedTotalBytes: 0,
      elapsedMs: 0,
      errorMessage: ''
    };
  }
}
