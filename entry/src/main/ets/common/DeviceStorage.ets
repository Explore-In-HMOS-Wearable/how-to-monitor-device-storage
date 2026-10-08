/** Device total and free space via `statfs`, measured on the sandbox path the app may read. */

import { statfs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { DeviceSpace } from '../model/StorageModels';

export class DeviceStorage {
  /** Async read of total + free bytes; the two independent statfs calls are issued together. */
  static async read(context: common.Context, path?: string): Promise<DeviceSpace> {
    const target: string = path ?? context.filesDir;
    try {
      const sizes: number[] = await Promise.all([
        statfs.getTotalSize(target),
        statfs.getFreeSize(target)
      ]);
      const totalBytes: number = sizes[0];
      const freeBytes: number = sizes[1];
      return {
        totalBytes: totalBytes,
        freeBytes: freeBytes,
        // statfs has no "used" call - used space is simply what is not free.
        usedBytes: Math.max(0, totalBytes - freeBytes),
        measuredPath: target,
        available: true
      };
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`[DeviceStorage] statfs failed on ${target}: code=${err.code} msg=${err.message}`);
      throw new Error(`Failed to read device space: ${err.message}`);
    }
  }

  /** Synchronous variant, kept for contrast: convenient, but it blocks the UI thread. */
  static readSync(context: common.Context, path?: string): DeviceSpace {
    const target: string = path ?? context.filesDir;
    let totalBytes: number = 0;
    let freeBytes: number = 0;
    // The sync forms throw rather than reject, so they need their own handling.
    try {
      totalBytes = statfs.getTotalSizeSync(target);
      freeBytes = statfs.getFreeSizeSync(target);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`[DeviceStorage] statfs sync failed on ${target}: code=${err.code} msg=${err.message}`);
      throw new Error(`Failed to read device space: ${err.message}`);
    }
    return {
      totalBytes: totalBytes,
      freeBytes: freeBytes,
      usedBytes: Math.max(0, totalBytes - freeBytes),
      measuredPath: target,
      available: true
    };
  }
}
