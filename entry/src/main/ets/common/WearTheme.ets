/** Wearable design tokens: AMOLED black ground, one accent, percentage margins for the circular safe area. */

export class WearTheme {
  /** AMOLED ground. */
  static readonly BG: string = '#000000';
  /** Card ground, one step up from black for the list surfaces. */
  static readonly SURFACE: string = '#141414';

  /** Primary text: full white, because contrast outdoors beats subtlety. */
  static readonly TEXT_PRIMARY: string = '#FFFFFF';
  /** Secondary text / row labels. */
  static readonly TEXT_SECONDARY: string = '#A9ADB8';
  /** Section captions, the quietest step that still passes contrast on black. */
  static readonly TEXT_TERTIARY: string = '#6B7280';

  /** The single accent. */
  static readonly ACCENT: string = '#0A59F7';
  /** Unfilled track of the ring gauge. */
  static readonly TRACK: string = '#2C2F36';
  /** Error state. */
  static readonly DANGER: string = '#F04A4A';

  /** Type scale, in vp. */
  static readonly FONT_HERO: number = 26;
  static readonly FONT_TITLE: number = 15;
  static readonly FONT_BODY: number = 13;
  static readonly FONT_CAPTION: number = 11;

  /** Side margin as a share of screen width - keeps content inside the circular safe area. */
  static readonly SIDE_MARGIN: string = '12%';
  /** Minimum row height; a 13vp label still needs a 40vp target. */
  static readonly ROW_HEIGHT: number = 40;
  /** Ring gauge diameter and stroke. */
  static readonly RING_SIZE: number = 116;
  static readonly RING_STROKE: number = 9;
  /** Gap between arc list items. */
  static readonly LIST_SPACE: number = 4;
  /** Room reserved at the bottom edge for the arc button on the glance card. */
  static readonly ACTION_CLEARANCE: number = 24;
  /** Room reserved for the dot indicator at 6 o'clock on the list cards. */
  static readonly INDICATOR_CLEARANCE: number = 16;
  /** Height of the list band: a round face is usable only across its middle, so rows sit in a centred band. */
  static readonly LIST_BAND: string = '66%';
}
