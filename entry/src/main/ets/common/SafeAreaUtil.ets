/** Status bar and bottom indicator insets, converted from px to vp so content clears the bezel. */

import { UIContext, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** Top and bottom insets, in vp. */
export interface SafeAreaInsets {
  top: number;
  bottom: number;
}

export class SafeAreaUtil {
  /** Zero insets, used until the real query returns. */
  static none(): SafeAreaInsets {
    return { top: 0, bottom: 0 };
  }

  /** Reads the current avoidance areas; never rejects - an unreadable window yields zero insets. */
  static async read(uiContext: UIContext): Promise<SafeAreaInsets> {
    try {
      const context = uiContext.getHostContext() as common.UIAbilityContext;
      const windowClass: window.Window = await window.getLastWindow(context);
      const statusBar: window.AvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const indicator: window.AvoidArea =
        windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      return {
        top: uiContext.px2vp(statusBar.topRect.height),
        bottom: uiContext.px2vp(indicator.bottomRect.height)
      };
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.warn(`[SafeAreaUtil] cannot read avoid areas: code=${err.code} msg=${err.message}`);
      return SafeAreaUtil.none();
    }
  }
}
