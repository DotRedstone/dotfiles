export interface ClashProviderSource {
  url: string;
  interval?: number;
  "health-check"?: {
    interval?: number;
  };
}

export function buildProfiles(input: {
  providers: Record<string, ClashProviderSource>;
  publicHost: string;
  subscriptionToken: string;
}): Record<"router" | "desktop" | "mobile" | "root", string>;
