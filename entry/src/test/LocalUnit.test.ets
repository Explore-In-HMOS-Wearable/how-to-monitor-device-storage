import { describe, it, expect } from '@ohos/hypium';
import { ByteFormatter } from '../main/ets/common/ByteFormatter';

/** Host-side unit tests for ByteFormatter, the one part of the pipeline with no file system. */
export default function localUnitTest() {
  describe('byteFormatterTest', () => {
    it('formatsWholeBytesWithoutFraction', 0, () => {
      expect(ByteFormatter.formatBytes(0)).assertEqual('0 B');
      expect(ByteFormatter.formatBytes(512)).assertEqual('512 B');
    });

    it('formatsAtUnitBoundaries', 0, () => {
      expect(ByteFormatter.formatBytes(1024)).assertEqual('1.00 KB');
      expect(ByteFormatter.formatBytes(1536)).assertEqual('1.50 KB');
      expect(ByteFormatter.formatBytes(1024 * 1024)).assertEqual('1.00 MB');
      expect(ByteFormatter.formatBytes(1024 * 1024 * 1024)).assertEqual('1.00 GB');
    });

    it('honoursDecimalsArgument', 0, () => {
      expect(ByteFormatter.formatBytes(1536, 0)).assertEqual('2 KB');
      expect(ByteFormatter.formatBytes(1536, 1)).assertEqual('1.5 KB');
    });

    it('keepsShortFormNarrowForWatchRows', 0, () => {
      // One decimal only while the mantissa is a single digit.
      expect(ByteFormatter.formatBytesShort(1024 * 1024 * 1024 * 1.25)).assertEqual('1.3 GB');
      expect(ByteFormatter.formatBytesShort(1024 * 1024 * 12)).assertEqual('12 MB');
      expect(ByteFormatter.formatBytesShort(1024 * 950)).assertEqual('950 KB');
    });

    it('survivesInvalidInput', 0, () => {
      expect(ByteFormatter.formatBytes(Number.NaN)).assertEqual('--');
      expect(ByteFormatter.formatBytes(Number.POSITIVE_INFINITY)).assertEqual('--');
      expect(ByteFormatter.formatBytesShort(-2048)).assertEqual('-2.0 KB');
    });

    it('survivesOutOfRangeDecimals', 0, () => {
      // toFixed throws outside 0..100, so a nonsense precision must be clamped, not passed through.
      expect(ByteFormatter.formatBytes(1536, -3)).assertEqual('2 KB');
      expect(ByteFormatter.formatBytes(1536, 1000).startsWith('1.5')).assertTrue();
      expect(ByteFormatter.formatPercent(3, 4, -1)).assertEqual('75%');
    });

    it('clampsPercent', 0, () => {
      expect(ByteFormatter.percent(1, 4)).assertEqual(25);
      // A zero whole must not produce NaN, or the ring gauge refuses to draw.
      expect(ByteFormatter.percent(5, 0)).assertEqual(0);
      expect(ByteFormatter.percent(9, 3)).assertEqual(100);
      expect(ByteFormatter.formatPercent(3, 4)).assertEqual('75%');
      expect(ByteFormatter.formatPercent(1, 0)).assertEqual('--');
    });
  });
}
