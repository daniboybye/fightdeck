import React, { useMemo } from 'react';
import {
  Image,
  ScrollView,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { useSurfaceLayout } from '../../core/src/ui/layout';
import { parseThemeJSON, type ThemeTokens } from '../../core/src/ui/theme';

interface FighterProps extends Record<string, unknown> {
  themeJSON: string;
  fighterJSON: string;
  portraitURL: string;
}

interface FighterRecord {
  wins: number;
  losses: number;
  noContests: number;
  display: string;
}

interface FighterData {
  name: string;
  nickname?: string | null;
  country?: string | null;
  heightCm?: number | null;
  reachIn?: number | null;
  stance?: string | null;
  record: FighterRecord;
}

function parseFighter(raw: string): FighterData | null {
  try {
    return JSON.parse(raw || '{}') as FighterData;
  } catch {
    return null;
  }
}

function capitalize(value: string): string {
  if (value.length === 0) {
    return value;
  }
  return value.charAt(0).toUpperCase() + value.slice(1);
}

export function FighterScreen(props: FighterProps) {
  const layoutFrame = useSurfaceLayout('FighterFeature');
  const theme = useMemo(() => parseThemeJSON(String(props.themeJSON ?? '{}')), [props.themeJSON]);
  const fighter = useMemo(() => parseFighter(String(props.fighterJSON ?? '{}')), [props.fighterJSON]);
  const portraitURL = String(props.portraitURL ?? '');
  const styles = useMemo(
    () => makeStyles(theme, layoutFrame.chromeBackground),
    [theme, layoutFrame.chromeBackground],
  );

  if (fighter == null) {
    return (
      <View style={[styles.root, styles.loadingRoot, { paddingTop: layoutFrame.safeAreaTop }]}>
        <Text style={styles.secondary}>Loading…</Text>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <ScrollView
        style={styles.flex}
        contentContainerStyle={[
          styles.content,
          { paddingTop: layoutFrame.safeAreaTop, paddingBottom: layoutFrame.safeAreaBottom },
        ]}
        contentInsetAdjustmentBehavior="never"
      >
        <Hero fighter={fighter} portraitURL={portraitURL} styles={styles} />

        <GroupedSection title="Profile" theme={theme}>
          <GroupedRow theme={theme}>
            <DetailRow label="Record" value={fighter.record.display} styles={styles} />
          </GroupedRow>
          <GroupedRow theme={theme}>
            <DetailRow label="Wins" value={String(fighter.record.wins)} styles={styles} />
          </GroupedRow>
          <GroupedRow theme={theme} isLast={fighter.record.noContests <= 0}>
            <DetailRow label="Losses" value={String(fighter.record.losses)} styles={styles} />
          </GroupedRow>
          {fighter.record.noContests > 0 ? (
            <GroupedRow theme={theme} isLast>
              <DetailRow label="No contests" value={String(fighter.record.noContests)} styles={styles} />
            </GroupedRow>
          ) : null}
        </GroupedSection>

        {(fighter.heightCm != null
          || fighter.reachIn != null
          || fighter.stance != null
          || fighter.country != null) ? (
          <GroupedSection title="Physicals" theme={theme}>
            {fighter.heightCm != null ? (
              <GroupedRow theme={theme} isLast={false}>
                <DetailRow label="Height" value={`${fighter.heightCm} cm`} styles={styles} />
              </GroupedRow>
            ) : null}
            {fighter.reachIn != null ? (
              <GroupedRow
                theme={theme}
                isLast={fighter.stance == null && fighter.country == null}
              >
                <DetailRow label="Reach" value={`${fighter.reachIn} in`} styles={styles} />
              </GroupedRow>
            ) : null}
            {fighter.stance != null ? (
              <GroupedRow theme={theme} isLast={fighter.country == null}>
                <DetailRow label="Stance" value={capitalize(fighter.stance)} styles={styles} />
              </GroupedRow>
            ) : null}
            {fighter.country != null ? (
              <GroupedRow theme={theme} isLast>
                <DetailRow label="Country" value={fighter.country} styles={styles} />
              </GroupedRow>
            ) : null}
          </GroupedSection>
        ) : null}
      </ScrollView>
    </View>
  );
}

function Hero({
  fighter,
  portraitURL,
  styles,
}: {
  fighter: FighterData;
  portraitURL: string;
  styles: ReturnType<typeof makeStyles>;
}) {
  return (
    <View style={styles.hero}>
      {portraitURL.length > 0 ? (
        <Image source={{ uri: portraitURL }} style={styles.heroImage} resizeMode="cover" />
      ) : (
        <View style={[styles.heroImage, styles.heroPlaceholder]} />
      )}
      <View style={styles.heroGradient} />
      <View style={styles.heroScrim}>
        <Text style={styles.heroName}>{fighter.name}</Text>
        {fighter.nickname ? (
          <Text style={styles.heroNickname}>“{fighter.nickname}”</Text>
        ) : null}
        <Text style={styles.heroRecord}>{fighter.record.display}</Text>
      </View>
    </View>
  );
}

function DetailRow({
  label,
  value,
  styles,
}: {
  label: string;
  value: string;
  styles: ReturnType<typeof makeStyles>;
}) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.body}>{label}</Text>
      <Text style={styles.secondary}>{value}</Text>
    </View>
  );
}

function GroupedSection({
  title,
  theme,
  children,
  style,
}: {
  title?: string;
  theme: ThemeTokens;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  const c = theme.colors;
  const s = theme.spacing;
  return (
    <View style={[{ marginBottom: s.lg ?? 16 }, style]}>
      {title ? <Text style={groupedStyles(c, theme).header}>{title}</Text> : null}
      <View style={groupedStyles(c, theme).group}>{children}</View>
    </View>
  );
}

function GroupedRow({
  theme,
  children,
  isLast = false,
}: {
  theme: ThemeTokens;
  children: React.ReactNode;
  isLast?: boolean;
}) {
  const c = theme.colors;
  const s = theme.spacing;
  return (
    <View>
      <View style={{ paddingHorizontal: s.lg ?? 16, paddingVertical: s.md ?? 12 }}>
        {children}
      </View>
      {!isLast ? <View style={[groupedStyles(c, theme).divider, { marginLeft: s.lg ?? 16 }]} /> : null}
    </View>
  );
}

function groupedStyles(c: Record<string, string>, theme: ThemeTokens) {
  const s = theme.spacing;
  const r = theme.radius;
  return StyleSheet.create({
    header: {
      color: c.textSecondary ?? '#9AA5B8',
      fontSize: theme.fontSize.callout ?? 17,
      marginBottom: s.sm ?? 8,
      marginHorizontal: s.lg ?? 16,
    },
    group: {
      backgroundColor: c.surface ?? '#141922',
      borderRadius: r.lg ?? 16,
      overflow: 'hidden',
    },
    divider: {
      height: StyleSheet.hairlineWidth,
      backgroundColor: c.border ?? '#232A38',
    },
  });
}

function makeStyles(theme: ReturnType<typeof parseThemeJSON>, chromeBackground: string) {
  const c = theme.colors;
  const s = theme.spacing;
  const pageBackground = chromeBackground || c.background || '#0B0E14';
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: pageBackground },
    flex: { flex: 1 },
    loadingRoot: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
    },
    content: { paddingHorizontal: s.lg ?? 16 },
    body: { color: c.textPrimary ?? '#F5F7FA', fontSize: theme.fontSize.body ?? 15 },
    secondary: { color: c.textSecondary ?? '#9AA5B8', fontSize: theme.fontSize.body ?? 15 },
    detailRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
    hero: {
      marginHorizontal: -(s.lg ?? 16),
      marginBottom: s.lg ?? 16,
      height: 320,
      overflow: 'hidden',
    },
    heroImage: {
      ...StyleSheet.absoluteFill,
      width: '100%',
      height: 320,
    },
    heroPlaceholder: {
      backgroundColor: c.surface ?? '#141922',
    },
    heroGradient: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      height: 200,
      backgroundColor: 'rgba(0,0,0,0.65)',
    },
    heroScrim: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      padding: s.lg ?? 16,
      gap: s.xs ?? 4,
    },
    heroName: {
      color: c.textPrimary ?? '#F5F7FA',
      fontSize: theme.fontSize.title ?? 22,
      fontWeight: '700',
    },
    heroNickname: {
      color: c.textSecondary ?? '#9AA5B8',
      fontSize: theme.fontSize.callout ?? 17,
    },
    heroRecord: {
      color: c.accent ?? '#E8B33C',
      fontSize: theme.fontSize.caption ?? 12,
      fontWeight: '600',
    },
  });
}
