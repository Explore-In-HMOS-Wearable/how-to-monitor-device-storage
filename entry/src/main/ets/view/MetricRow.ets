/** One label/value row; a @Component with @Prop, because a by-value @Builder would never update. */

import { WearTheme } from '../common/WearTheme';

@Component
export struct MetricRow {
  @Prop label: string;
  @Prop value: string;
  /** Marks the one value on the card that the glance is actually for. */
  @Prop emphasis: boolean;

  build() {
    Row() {
      Text(this.label)
        .fontSize(WearTheme.FONT_BODY)
        .fontColor(this.emphasis ? WearTheme.TEXT_PRIMARY : WearTheme.TEXT_SECONDARY)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      // The value column is right-aligned so units line up down the card.
      Text(this.value)
        .fontSize(WearTheme.FONT_BODY)
        .fontColor(this.emphasis ? WearTheme.ACCENT : WearTheme.TEXT_PRIMARY)
        .fontWeight(this.emphasis ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1);
    }
    .width('100%')
    .height(WearTheme.ROW_HEIGHT)
    .padding({ left: 14, right: 14 })
    .borderRadius(WearTheme.ROW_HEIGHT / 2)
    .backgroundColor(WearTheme.SURFACE);
  }
}
