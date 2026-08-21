import { libVersion } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  async onPrompt(ctx) {
    if (ctx.message.type !== "CHECK_DUT_METADATA") return;

    const { property, expected } = ctx.message;
    let actual: number | undefined;

    switch (property) {
      case "MANUFACTURER_ID":
        actual = ctx.driver.options.vendor?.manufacturerId;
        break;
      case "PRODUCT_TYPE_ID":
        actual = ctx.driver.options.vendor?.productType;
        break;
      case "PRODUCT_ID":
        actual = ctx.driver.options.vendor?.productId;
        break;
      case "HARDWARE_VERSION":
        actual = ctx.driver.options.vendor?.hardwareVersion;
        break;
      case "FIRMWARE_VERSION": {
        const firmwareVersions = [
          ctx.driver.controller.firmwareVersion,
          libVersion,
        ];
        const firmwareVersion = firmwareVersions[ctx.message.firmwareIndex];
        if (firmwareVersion) {
          const [version, subVersion] = firmwareVersion
            .split(".")
            .map((part) => Number.parseInt(part, 10));
          actual =
            ctx.message.component === "VERSION" ? version : subVersion;
        }
        break;
      }
    }

    return actual === expected ? "Yes" : "No";
  },
});
