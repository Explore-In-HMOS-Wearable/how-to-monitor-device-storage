/** Byte formatting for display, in binary units because the file system counts in them. */

const UNITS: string[] = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
const STEP: number = 1024;
/** `toFixed` throws RangeError outside 0..100, so every caller-supplied precision is clamped. */
const MAX_DECIMALS: number = 100;

export class ByteFormatter {
  /** Full form: `formatBytes(1536)` -> `1.50 KB`. Whole bytes never carry a fraction. */
  static formatBytes(bytes: number, decimals: number = 2): string {
    if (!ByteFormatter.isUsable(bytes)) {
      return '--';
    }
    const negative: boolean = bytes < 0;
    let value: number = Math.abs(bytes);
    let unitIndex: number = 0;
    // Walk up the unit table until the value fits into three integer digits.
    while (value >= STEP && unitIndex < UNITS.length - 1) {
      value = value / STEP;
      unitIndex++;
    }
    // Whole bytes never need a fraction.
    const digits: number = unitIndex === 0 ? 0 : ByteFormatter.clampDecimals(decimals);
    const text: string = value.toFixed(digits);
    return `${negative ? '-' : ''}${text} ${UNITS[unitIndex]}`;
  }

  /** Compact form for the six-character value column of a watch row: `950 MB`, `1.2 GB`, `120 GB`. */
  static formatBytesShort(bytes: number): string {
    if (!ByteFormatter.isUsable(bytes)) {
      return '--';
    }
    const negative: boolean = bytes < 0;
    let value: number = Math.abs(bytes);
    let unitIndex: number = 0;
    while (value >= STEP && unitIndex < UNITS.length - 1) {
      value = value / STEP;
      unitIndex++;
    }
    // One decimal only while the mantissa is a single digit, so the string never exceeds 5 chars.
    const digits: number = (unitIndex === 0 || value >= 10) ? 0 : 1;
    return `${negative ? '-' : ''}${value.toFixed(digits)} ${UNITS[unitIndex]}`;
  }

  /** Share of `whole` taken by `part`, clamped to 0..100; 0 for an unusable whole so the ring can draw. */
  static percent(part: number, whole: number): number {
    if (!ByteFormatter.isUsable(part) || !ByteFormatter.isUsable(whole) || whole <= 0) {
      return 0;
    }
    const ratio: number = (part / whole) * 100;
    return Math.min(100, Math.max(0, ratio));
  }

  /** `formatPercent(3, 4)` -> `75%`. */
  static formatPercent(part: number, whole: number, decimals: number = 0): string {
    if (!ByteFormatter.isUsable(whole) || whole <= 0) {
      return '--';
    }
    return `${ByteFormatter.percent(part, whole).toFixed(ByteFormatter.clampDecimals(decimals))}%`;
  }

  /** Keeps a caller-supplied precision inside the range `toFixed` accepts. */
  private static clampDecimals(decimals: number): number {
    if (Number.isNaN(decimals)) {
      return 0;
    }
    return Math.min(MAX_DECIMALS, Math.max(0, Math.floor(decimals)));
  }

  /** Guards against NaN/Infinity coming back from a failed query. */
  private static isUsable(value: number): boolean {
    return !Number.isNaN(value) && Number.isFinite(value);
  }
}
