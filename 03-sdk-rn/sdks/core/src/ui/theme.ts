export interface ThemeTokens {
  colors: Record<string, string>;
  spacing: Record<string, number>;
  radius: Record<string, number>;
  fontSize: Record<string, number>;
}

export function parseThemeJSON(themeJSON: string): ThemeTokens {
  const raw = JSON.parse(themeJSON) as Record<string, unknown>;
  const colors: Record<string, string> = {};
  const colorBlock = raw.color as Record<string, { $value?: { hex?: string } }>;
  for (const [key, value] of Object.entries(colorBlock ?? {})) {
    if (key.startsWith('$')) {
      continue;
    }
    const hex = value?.$value?.hex;
    if (hex) {
      colors[key] = hex;
    }
  }
  const spacing = dimensionGroup(raw.spacing as Record<string, { $value?: { value?: number } }>);
  const radius = dimensionGroup(raw.radius as Record<string, { $value?: { value?: number } }>);
  const fontSize = dimensionGroup(raw.fontSize as Record<string, { $value?: { value?: number } }>);
  return { colors, spacing, radius, fontSize };
}

function dimensionGroup(
  block: Record<string, { $value?: { value?: number } }> | undefined,
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const [key, value] of Object.entries(block ?? {})) {
    if (key.startsWith('$')) {
      continue;
    }
    const n = value?.$value?.value;
    if (typeof n === 'number') {
      out[key] = n;
    }
  }
  return out;
}

export function slipSummaryRows(state: {
  combinedOddsDisplay: string | null;
  totalStake: string;
  potentialReturn: string;
  potentialProfit: string;
}): Array<{ label: string; value: string }> {
  const rows: Array<{ label: string; value: string }> = [
    { label: 'Total stake', value: state.totalStake },
  ];
  if (state.combinedOddsDisplay) {
    rows.push({ label: 'Combined odds', value: state.combinedOddsDisplay });
  }
  rows.push(
    { label: 'Potential return', value: state.potentialReturn },
    { label: 'Potential profit', value: state.potentialProfit },
  );
  return rows;
}
