/** App footprint via `getCurrentBundleStats()`: no permission needed, but a syscap that may be absent. */

import { storageStatistics } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppSpace, EmptyStorage } from '../model/StorageModels';

/** Capability that carries the whole storageStatistics module. */
const SPATIAL_STATISTICS: string = 'SystemCapability.FileManagement.StorageService.SpatialStatistics';

export class BundleStorage {
  /** True when this device exposes the storageStatistics module at all. */
  static isSupported(): boolean {
    return canIUse(SPATIAL_STATISTICS);
  }

  /** Reads BundleStats into AppSpace, returning an unavailable AppSpace rather than throwing. */
  static async read(): Promise<AppSpace> {
    // The check must appear literally here; the compiler rejects a boolean field as the guard.
    if (canIUse('SystemCapability.FileManagement.StorageService.SpatialStatistics')) {
      try {
        const stats: storageStatistics.BundleStats = await storageStatistics.getCurrentBundleStats();
        return {
          appSize: stats.appSize,
          cacheSize: stats.cacheSize,
          dataSize: stats.dataSize,
          totalSize: stats.appSize + stats.cacheSize + stats.dataSize,
          available: true
        };
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        console.error(`[BundleStorage] getCurrentBundleStats failed: code=${err.code} msg=${err.message}`);
        return EmptyStorage.app();
      }
    }
    console.warn('[BundleStorage] storageStatistics is not available on this device; use the walk.');
    return EmptyStorage.app();
  }
}
