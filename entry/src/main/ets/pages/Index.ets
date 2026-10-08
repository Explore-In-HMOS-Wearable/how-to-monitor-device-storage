/** Wearable storage screen: three arc-paged cards - device ring, app usage, sandbox walk. */

import { common } from '@kit.AbilityKit';
// The Arc* components need their *Attribute classes imported too, or the generated code fails.
import {
  ArcButton,
  ArcButtonOptions,
  ArcButtonPosition,
  ArcButtonStatus,
  ArcButtonStyleMode,
  ArcDirection,
  ArcDotIndicator,
  ArcList,
  ArcListAttribute,
  ArcListItem,
  ArcListItemAttribute,
  ArcSwiper,
  ArcSwiperAttribute,
  LengthMetrics
} from '@kit.ArkUI';
import { ByteFormatter } from '../common/ByteFormatter';
import { SafeAreaInsets, SafeAreaUtil } from '../common/SafeAreaUtil';
import { WearTheme } from '../common/WearTheme';
import { MetricRow } from '../view/MetricRow';
import { StorageViewModel } from '../viewmodel/StorageViewModel';
import { DirUsage, EmptyStorage, StorageSnapshot } from '../model/StorageModels';

/** One rendered line of a card list. */
class MetricItem {
  key: string;
  label: string;
  value: string;
  emphasis: boolean;

  constructor(key: string, label: string, value: string, emphasis: boolean) {
    this.key = key;
    this.label = label;
    this.value = value;
    this.emphasis = emphasis;
  }
}

@Entry
@Component
struct Index {
  @State snapshot: StorageSnapshot = EmptyStorage.snapshot();
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State pageIndex: number = 0;
  /** Status bar / bottom indicator insets, applied to the card content. */
  @State insets: SafeAreaInsets = SafeAreaUtil.none();

  aboutToAppear(): void {
    SafeAreaUtil.read(this.getUIContext()).then((value: SafeAreaInsets) => {
      this.insets = value;
    });
    this.refresh();
  }

  /** Pulls a fresh snapshot. The view model never throws, so failures arrive inside the result. */
  refresh(): void {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    StorageViewModel.refresh(context).then((result: StorageSnapshot) => {
      // Filter the log on `StorageScreen`: real numbers here with a blank screen means a render bug.
      console.info(`[StorageScreen] total=${result.device.totalBytes} free=${result.device.freeBytes}` +
        ` appTotal=${result.app.totalSize} roots=${result.roots.length}` +
        ` walked=${result.walkedTotalBytes} elapsed=${result.elapsedMs}ms`);
      this.snapshot = result;
      // The view model reports failures through the snapshot rather than by rejecting.
      this.errorMessage = result.errorMessage;
      this.isLoading = false;
    }).catch((error: Error) => {
      // Defensive only: refresh() is documented never to reject.
      this.errorMessage = error.message;
      this.isLoading = false;
    });
  }

  /** Rows for card 2; values read `--` without the SpatialStatistics capability, never a false 0 B. */
  private appRows(): MetricItem[] {
    const snap: StorageSnapshot = this.snapshot;
    const ok: boolean = snap.app.available;
    return [
      new MetricItem('app-install', 'Install', ok ? ByteFormatter.formatBytesShort(snap.app.appSize) : '--', false),
      new MetricItem('app-data', 'Data', ok ? ByteFormatter.formatBytesShort(snap.app.dataSize) : '--', false),
      new MetricItem('app-cache', 'Cache', ok ? ByteFormatter.formatBytesShort(snap.app.cacheSize) : '--', false),
      new MetricItem('app-total', 'Total', ok ? ByteFormatter.formatBytesShort(snap.app.totalSize) : '--', true)
    ];
  }

  /** Rows for card 3 - the recursive sandbox walk. */
  private walkRows(): MetricItem[] {
    const snap: StorageSnapshot = this.snapshot;
    const items: MetricItem[] = [];
    if (snap.roots.length === 0) {
      // An empty walk must look different from a list that failed to draw.
      const label: string = this.isLoading ? 'measuring' : 'no directories';
      items.push(new MetricItem('walk-none', label, '--', false));
    }
    snap.roots.forEach((root: DirUsage) => {
      // A trailing `*` marks a root the walk could not read in full, so a partial sum is not read as whole.
      const incomplete: string = root.errorCount > 0 ? '*' : '';
      const label: string = `${root.name} (${root.fileCount})${incomplete}`;
      items.push(new MetricItem(`root-${root.path}`, label, ByteFormatter.formatBytesShort(root.sizeBytes), false));
    });
    items.push(new MetricItem('walk-total', 'Walked', ByteFormatter.formatBytesShort(snap.walkedTotalBytes), true));
    items.push(new MetricItem('walk-ms', 'Took', `${snap.elapsedMs} ms`, false));
    return items;
  }

  /** Caption under the ring; says so plainly instead of printing a percentage of an unknown total. */
  private deviceCaption(): string {
    if (this.isLoading) {
      return 'Measuring…';
    }
    if (!this.snapshot.device.available) {
      return 'Device space unavailable';
    }
    return `${ByteFormatter.formatPercent(this.snapshot.device.usedBytes, this.snapshot.device.totalBytes)}` +
      ` of ${ByteFormatter.formatBytesShort(this.snapshot.device.totalBytes)} used`;
  }

  /** Card 1 - the glance: one number in a ring, with the detail one swipe away. */
  @Builder
  deviceCard() {
    Column() {
      Stack() {
        Progress({
          value: ByteFormatter.percent(this.snapshot.device.usedBytes, this.snapshot.device.totalBytes),
          total: 100,
          type: ProgressType.Ring
        })
          .width(WearTheme.RING_SIZE)
          .height(WearTheme.RING_SIZE)
          .color(WearTheme.ACCENT)
          .backgroundColor(WearTheme.TRACK)
          .style({ strokeWidth: WearTheme.RING_STROKE, enableSmoothEffect: true });

        Column({ space: 2 }) {
          // `--` rather than `0 B`: a zero would claim the watch is completely full.
          Text(this.snapshot.device.available ?
            ByteFormatter.formatBytesShort(this.snapshot.device.freeBytes) : '--')
            .fontSize(WearTheme.FONT_HERO)
            .fontWeight(FontWeight.Bold)
            .fontColor(WearTheme.TEXT_PRIMARY);
          Text('free')
            .fontSize(WearTheme.FONT_CAPTION)
            .fontColor(WearTheme.TEXT_TERTIARY);
        };
      }
      .margin({ bottom: 8 });

      Text(this.deviceCaption())
        .fontSize(WearTheme.FONT_CAPTION)
        .fontColor(WearTheme.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .maxLines(1);

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(WearTheme.FONT_CAPTION)
          .fontColor(WearTheme.DANGER)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .margin({ top: 4 });
      }
    }
    .width('100%')
    .height('100%')
    // Centred on both axes: on a round face the centre is the only fully visible place.
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    // Side margin is a share of width, so content stays inside the circle on any watch size.
    .padding({
      left: WearTheme.SIDE_MARGIN,
      right: WearTheme.SIDE_MARGIN,
      top: this.insets.top,
      // Only enough to clear the arc button; more would pull the ring off centre.
      bottom: this.insets.bottom + WearTheme.ACTION_CLEARANCE
    });
  }

  /** Card 2 - what this app is made of. */
  @Builder
  appCard() {
    Column() {
      Text('App usage')
        .fontSize(WearTheme.FONT_TITLE)
        .fontColor(WearTheme.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 8 });

      if (canIUse('SystemCapability.ArkUI.ArkUI.Circle')) {
        // autoScale shrinks and fades items towards the bezel, which is what makes the list feel native.
        ArcList() {
          ForEach(this.appRows(), (item: MetricItem) => {
            ArcListItem() {
              MetricRow({ label: item.label, value: item.value, emphasis: item.emphasis });
            }
            .autoScale(true);
            // The key carries the value, or ForEach would keep the old figure after a refresh.
          }, (item: MetricItem) => `${item.key}#${item.value}`);
        }
        .space(LengthMetrics.vp(WearTheme.LIST_SPACE))
        .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
        .fadingEdge(true)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(WearTheme.LIST_BAND);
      } else {
        List({ space: WearTheme.LIST_SPACE }) {
          ForEach(this.appRows(), (item: MetricItem) => {
            ListItem() {
              MetricRow({ label: item.label, value: item.value, emphasis: item.emphasis });
            }
          }, (item: MetricItem) => `${item.key}#${item.value}`);
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height(WearTheme.LIST_BAND);
      }
    }
    .width('100%')
    .height('100%')
    // Title and list band are centred as a group, so the card reads from the middle outwards.
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: WearTheme.SIDE_MARGIN,
      right: WearTheme.SIDE_MARGIN,
      top: this.insets.top,
      // Clearance so the last row does not collide with the dot indicator at 6 o'clock.
      bottom: this.insets.bottom + WearTheme.INDICATOR_CLEARANCE
    });
  }

  /** Card 3 - where the bytes actually sit. */
  @Builder
  walkCard() {
    Column() {
      Text('Sandbox walk')
        .fontSize(WearTheme.FONT_TITLE)
        .fontColor(WearTheme.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 8 });

      if (canIUse('SystemCapability.ArkUI.ArkUI.Circle')) {
        ArcList() {
          ForEach(this.walkRows(), (item: MetricItem) => {
            ArcListItem() {
              MetricRow({ label: item.label, value: item.value, emphasis: item.emphasis });
            }
            .autoScale(true);
          }, (item: MetricItem) => `${item.key}#${item.value}`);
        }
        .space(LengthMetrics.vp(WearTheme.LIST_SPACE))
        .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
        .fadingEdge(true)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(WearTheme.LIST_BAND);
      } else {
        List({ space: WearTheme.LIST_SPACE }) {
          ForEach(this.walkRows(), (item: MetricItem) => {
            ListItem() {
              MetricRow({ label: item.label, value: item.value, emphasis: item.emphasis });
            }
          }, (item: MetricItem) => `${item.key}#${item.value}`);
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height(WearTheme.LIST_BAND);
      }
    }
    .width('100%')
    .height('100%')
    // Title and list band are centred as a group, so the card reads from the middle outwards.
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: WearTheme.SIDE_MARGIN,
      right: WearTheme.SIDE_MARGIN,
      top: this.insets.top,
      // Clearance so the last row does not collide with the dot indicator at 6 o'clock.
      bottom: this.insets.bottom + WearTheme.INDICATOR_CLEARANCE
    });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (canIUse('SystemCapability.ArkUI.ArkUI.Circle')) {
        // ArcSwiper pages with an arc-aware gesture and supports the crown.
        ArcSwiper() {
          this.deviceCard();
          this.appCard();
          this.walkCard();
        }
        .index(this.pageIndex)
        // Dots at 6 o'clock - where the wearable guidance puts a page indicator.
        .indicator(new ArcDotIndicator()
          .arcDirection(ArcDirection.SIX_CLOCK_DIRECTION)
          .itemColor(WearTheme.TRACK)
          .selectedItemColor(WearTheme.ACCENT))
        .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
        .onChange((index: number) => {
          this.pageIndex = index;
        })
        .width('100%')
        .height('100%');

        // Only the glance card carries the action; on a detail card it would cover a row.
        if (this.pageIndex === 0) {
          // The primary action, curved along the bottom edge.
          ArcButton({
            options: new ArcButtonOptions({
              position: ArcButtonPosition.BOTTOM_EDGE,
              styleMode: ArcButtonStyleMode.EMPHASIZED_DARK,
              status: this.isLoading ? ArcButtonStatus.DISABLED : ArcButtonStatus.NORMAL,
              label: this.isLoading ? 'Refreshing' : 'Refresh',
              onClick: () => {
                this.refresh();
              }
            })
          });
        }
      } else {
        Swiper() {
          this.deviceCard();
          this.appCard();
          this.walkCard();
        }
        .index(this.pageIndex)
        .indicator(true)
        .loop(false)
        .onChange((index: number) => {
          this.pageIndex = index;
        })
        .width('100%')
        .height('100%');

        if (this.pageIndex === 0) {
          Button(this.isLoading ? 'Refreshing' : 'Refresh')
            .enabled(!this.isLoading)
            .fontSize(WearTheme.FONT_BODY)
            .height(40)
            .width('60%')
            .margin({ bottom: 24 })
            .backgroundColor(WearTheme.ACCENT)
            .onClick(() => {
              this.refresh();
            });
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(WearTheme.BG)
    // Full bleed: the pager and arc button need the edges, so margins are applied per card.
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}
