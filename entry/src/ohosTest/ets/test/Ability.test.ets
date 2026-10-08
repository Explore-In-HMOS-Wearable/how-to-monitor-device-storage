/** On-device tests for the storage pipeline; assertions are invariants, since real figures vary. */

import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { BundleStorage } from '../../../main/ets/common/BundleStorage';
import { DeviceStorage } from '../../../main/ets/common/DeviceStorage';
import { DirectorySizer } from '../../../main/ets/common/DirectorySizer';
import { SandboxRoot, StorageViewModel } from '../../../main/ets/viewmodel/StorageViewModel';
import { AppSpace, DeviceSpace, DirUsage, StorageSnapshot } from '../../../main/ets/model/StorageModels';

const DOMAIN: number = 0x0001;
const TAG: string = 'StorageMonitor.AbilityTest';

/** Size of the probe file written into the sandbox so the walk has a known quantity to find. */
const PROBE_BYTES: number = 4096;
const PROBE_DIR: string = 'sizer_probe';
const PROBE_FILE: string = 'probe.bin';

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    let context: common.Context;
    let probeDir: string = '';

    beforeAll(() => {
      const delegator: abilityDelegatorRegistry.AbilityDelegator =
        abilityDelegatorRegistry.getAbilityDelegator();
      context = delegator.getAppContext();

      // A directory of known content, so the walk assertions do not depend on leftovers.
      probeDir = `${context.filesDir}/${PROBE_DIR}`;
      const probePath: string = `${probeDir}/${PROBE_FILE}`;
      try {
        if (!fileIo.accessSync(probeDir)) {
          fileIo.mkdirSync(probeDir);
        }
        const file: fileIo.File = fileIo.openSync(probePath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, new ArrayBuffer(PROBE_BYTES));
        fileIo.closeSync(file);
        hilog.info(DOMAIN, TAG, 'probe written at %{public}s', probePath);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'cannot write probe: %{public}s', JSON.stringify(error));
      }
    });

    afterAll(() => {
      // Leaving the probe behind would inflate the next run's figures.
      try {
        fileIo.rmdirSync(probeDir);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'cannot remove probe dir: %{public}s', JSON.stringify(error));
      }
    });

    /** statfs must return a self-consistent triple; `usedBytes` is computed, not reported. */
    it('deviceSpaceIsSelfConsistent', 0, async (done: () => void) => {
      const space: DeviceSpace = await DeviceStorage.read(context);
      hilog.info(DOMAIN, TAG, 'device total=%{public}d free=%{public}d', space.totalBytes, space.freeBytes);

      expect(space.available).assertTrue();
      expect(space.totalBytes > 0).assertTrue();
      expect(space.freeBytes >= 0).assertTrue();
      expect(space.freeBytes <= space.totalBytes).assertTrue();
      expect(space.usedBytes).assertEqual(space.totalBytes - space.freeBytes);
      expect(space.measuredPath).assertEqual(context.filesDir);
      done();
    });

    /** The sync variant exists for the codelab's contrast; it must agree with the async one. */
    it('syncReadAgreesWithAsyncRead', 0, async (done: () => void) => {
      const asyncSpace: DeviceSpace = await DeviceStorage.read(context);
      const syncSpace: DeviceSpace = DeviceStorage.readSync(context);

      expect(syncSpace.totalBytes).assertEqual(asyncSpace.totalBytes);
      // Free space can move between the two calls, so only the total is compared exactly.
      expect(syncSpace.available).assertTrue();
      done();
    });

    /** `isSupported()` and the `available` flag must agree, or the App card hides or invents figures. */
    it('bundleStatsMatchDeclaredCapability', 0, async (done: () => void) => {
      const supported: boolean = BundleStorage.isSupported();
      const space: AppSpace = await BundleStorage.read();
      hilog.info(DOMAIN, TAG, 'spatial statistics supported=%{public}s', supported ? 'yes' : 'no');

      if (!supported) {
        // No capability: the model must say so, not report a zeroed but available reading.
        expect(space.available).assertFalse();
        expect(space.totalSize).assertEqual(0);
        done();
        return;
      }
      expect(space.available).assertTrue();
      expect(space.appSize >= 0).assertTrue();
      expect(space.totalSize).assertEqual(space.appSize + space.cacheSize + space.dataSize);
      done();
    });

    /** The walk must actually see bytes that exist - the probe is there precisely to be found. */
    it('walkFindsTheProbeFile', 0, async (done: () => void) => {
      const usage: DirUsage = await DirectorySizer.measure(probeDir, PROBE_DIR);

      expect(usage.name).assertEqual(PROBE_DIR);
      expect(usage.fileCount).assertEqual(1);
      expect(usage.errorCount).assertEqual(0);
      expect(usage.sizeBytes).assertEqual(PROBE_BYTES);
      done();
    });

    /** The two walk strategies are each other's oracle: a recursion bug shows up as a disagreement. */
    it('recursiveWalkAgreesWithFlatWalk', 0, async (done: () => void) => {
      const walked: DirUsage = await DirectorySizer.measure(context.filesDir, 'files');
      const flat: number = await DirectorySizer.measureFlat(context.filesDir);
      hilog.info(DOMAIN, TAG, 'walk=%{public}d flat=%{public}d', walked.sizeBytes, flat);

      expect(walked.sizeBytes).assertEqual(flat);
      done();
    });

    /** `children` is documented as one level deep; a deeper tree would be memory nobody reads. */
    it('walkKeepsOnlyOneLevelOfChildren', 0, async (done: () => void) => {
      const usage: DirUsage = await DirectorySizer.measure(context.filesDir, 'files');

      // The probe directory is an immediate child of filesDir, so there is at least one to inspect.
      expect(usage.children.length > 0).assertTrue();
      usage.children.forEach((child: DirUsage) => {
        expect(child.children.length).assertEqual(0);
      });
      done();
    });

    /** Depth 0 means "this directory's own files only", and unmeasured subdirectories are counted. */
    it('respectsTheDepthCap', 0, async (done: () => void) => {
      const capped: DirUsage = await DirectorySizer.measure(context.filesDir, 'files', 0);

      expect(capped.children.length).assertEqual(0);
      // The probe directory could not be descended into, so it must register as unmeasured.
      expect(capped.errorCount > 0).assertTrue();
      done();
    });

    /** A missing path is a normal condition, not a crash: it comes back flagged, not thrown. */
    it('toleratesAMissingDirectory', 0, async (done: () => void) => {
      const missing: DirUsage = await DirectorySizer.measure(`${context.filesDir}/does_not_exist`, 'ghost');

      expect(missing.sizeBytes).assertEqual(0);
      expect(missing.fileCount).assertEqual(0);
      expect(missing.errorCount).assertEqual(1);
      done();
    });

    /** The snapshot the UI binds to: totals must add up and the roots must be sorted for display. */
    it('refreshProducesAConsistentSnapshot', 0, async (done: () => void) => {
      const snapshot: StorageSnapshot = await StorageViewModel.refresh(context);
      hilog.info(DOMAIN, TAG, 'snapshot roots=%{public}d elapsed=%{public}dms',
        snapshot.roots.length, snapshot.elapsedMs);

      expect(snapshot.errorMessage).assertEqual('');
      expect(snapshot.device.available).assertTrue();
      expect(snapshot.roots.length > 0).assertTrue();
      expect(snapshot.elapsedMs >= 0).assertTrue();

      let sum: number = 0;
      snapshot.roots.forEach((root: DirUsage) => {
        sum += root.sizeBytes;
      });
      expect(snapshot.walkedTotalBytes).assertEqual(sum);

      // Biggest consumer first; the card renders this order without re-sorting.
      for (let i = 1; i < snapshot.roots.length; i++) {
        expect(snapshot.roots[i - 1].sizeBytes >= snapshot.roots[i].sizeBytes).assertTrue();
      }
      done();
    });

    /** Every root handed to the walk must be a usable absolute sandbox path. */
    it('exposesTheSandboxRoots', 0, () => {
      const roots: SandboxRoot[] = StorageViewModel.sandboxRoots(context);

      expect(roots.length > 0).assertTrue();
      roots.forEach((root: SandboxRoot) => {
        expect(root.path.length > 0).assertTrue();
        expect(root.name.length > 0).assertTrue();
      });
    });
  });
}
