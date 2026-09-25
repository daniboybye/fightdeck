package com.fightdeck.rust.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fightdeck.rust.design.BalanceMenuAction
import com.fightdeck.rust.design.Tokens
import uniffi.fightcore.formatCurrency
import uniffi.fightevents.BoutSummary
import uniffi.fightevents.CornerSummary
import uniffi.fightevents.EventCatalog
import uniffi.fightevents.EventSummary
import uniffi.fightevents.MediaItem
import uniffi.fightevents.NewsItem
import uniffi.fightslip.BetSlipRecord

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EventListScreen(
    state: LoadState<List<EventSummary>>,
    news: LoadState<List<NewsItem>>,
    media: LoadState<List<MediaItem>>,
    mode: EventMode,
    viewModel: MainViewModel,
    balance: String,
    onDeposit: () -> Unit,
    onRetry: () -> Unit,
    onEventClick: (EventSummary) -> Unit,
    onArticleClick: (NewsItem) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
) {
    val scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior(rememberTopAppBarState())

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(mode.title, style = MaterialTheme.typography.headlineMedium) },
                scrollBehavior = scrollBehavior,
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    BalanceMenuAction(
                        balanceLabel = formatCurrency(balance),
                        onDeposit = onDeposit,
                    )
                },
            )
        },
    ) { padding ->
        when (state) {
            LoadState.Loading -> SkeletonColumn(Modifier.padding(padding))
            is LoadState.Empty -> EmptyState("No events", Modifier.padding(padding))
            is LoadState.Error -> ErrorState(onRetry, Modifier.padding(padding))
            is LoadState.Loaded -> LazyColumn(
                contentPadding = PaddingValues(
                    start = Tokens.spacingLg,
                    end = Tokens.spacingLg,
                    top = padding.calculateTopPadding(),
                    bottom = Tokens.spacingXl,
                ),
                verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
            ) {
                items(state.value, key = { it.id }) { event ->
                    EventCard(
                        event = event,
                        mode = mode,
                        posterUrl = viewModel.imageUrl(event.posterPath),
                        onClick = { onEventClick(event) },
                    )
                }
                if (mode.showsResults) {
                    val articles = (news as? LoadState.Loaded)?.value.orEmpty()
                    if (articles.isNotEmpty()) {
                        item {
                            SectionHeader("News")
                        }
                        items(articles, key = { it.id }) { article ->
                            NewsCard(
                                item = article,
                                eventName = state.value.firstOrNull { it.id == article.eventId }?.name.orEmpty(),
                                imageUrl = viewModel.imageUrl(article.heroImage),
                                onClick = { onArticleClick(article) },
                            )
                        }
                    }
                    val clips = (media as? LoadState.Loaded)?.value.orEmpty()
                    if (clips.isNotEmpty()) {
                        item {
                            SectionHeader("Video")
                        }
                        items(clips, key = { it.id }) { clip ->
                            VideoCard(
                                item = clip,
                                eventName = state.value.firstOrNull { it.id == clip.eventId }?.name.orEmpty(),
                                posterUrl = viewModel.imageUrl(clip.poster),
                                onClick = { onVideoClick(clip) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun VideoCard(
    item: MediaItem,
    eventName: String,
    posterUrl: String?,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(Tokens.radiusMd)),
            ) {
                RemoteImage(
                    url = posterUrl,
                    modifier = Modifier.fillMaxSize(),
                )
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .size(44.dp),
                )
                Surface(
                    color = Color.Black.copy(alpha = 0.6f),
                    shape = RoundedCornerShape(percent = 50),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(Tokens.spacingSm),
                ) {
                    Text(
                        item.durationLabel,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        modifier = Modifier.padding(
                            horizontal = Tokens.spacingSm,
                            vertical = Tokens.spacingXs,
                        ),
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs)) {
                if (eventName.isNotEmpty()) {
                    Text(
                        eventName.uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = Tokens.accent,
                    )
                }
                Text(item.title, style = MaterialTheme.typography.titleMedium, maxLines = 2)
            }
        }
    }
}

@Composable
private fun EventCard(event: EventSummary, mode: EventMode, posterUrl: String?, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        RemoteImage(
            url = posterUrl,
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp),
        )
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs),
        ) {
            Text(event.name, style = MaterialTheme.typography.titleLarge)
            Text(
                event.locationLine,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${event.date.displayDate} · ${event.boutCount} fights",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                StatusBadge(mode)
            }
        }
    }
}

@Composable
private fun StatusBadge(mode: EventMode) {
    val tint = if (mode.showsResults) Tokens.positive else Tokens.accent
    Surface(color = tint.copy(alpha = 0.15f), shape = RoundedCornerShape(Tokens.radiusLg)) {
        Text(
            if (mode.showsResults) "FINISHED" else "OPEN",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = tint,
            modifier = Modifier.padding(horizontal = Tokens.spacingSm, vertical = Tokens.spacingXs),
        )
    }
}

@Composable
private fun NewsCard(item: NewsItem, eventName: String, imageUrl: String?, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        RemoteImage(
            url = imageUrl,
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp),
        )
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs),
        ) {
            // Every article carries its event, and the feed mixes both cards, so the row has to
            // say which event it belongs to.
            if (eventName.isNotEmpty()) {
                Text(
                    eventName.uppercase(),
                    style = MaterialTheme.typography.labelSmall,
                    color = Tokens.accent,
                )
            }
            Text(item.headline, style = MaterialTheme.typography.titleMedium, maxLines = 3)
            Text(
                item.body,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
            )
            Text(
                "${item.readMinutes} min read",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EventDetailScreen(
    event: EventSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
    media: LoadState<List<MediaItem>>,
    balance: String,
    onDeposit: () -> Unit,
    onBoutClick: (BoutSummary) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    val sections = viewModel.requireCatalog().cardSections(event.id)
    DetailScaffold(title = event.name, onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                start = Tokens.spacingLg,
                end = Tokens.spacingLg,
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            sections.forEach { section ->
                item { SectionHeader(section.title) }
                items(section.bouts, key = { it.id }) { bout ->
                    BoutRow(bout, mode, slip, viewModel, onClick = { onBoutClick(bout) })
                }
            }
            if (mode.showsResults) {
                val clips = (media as? LoadState.Loaded)?.value.orEmpty().filter { it.eventId == event.id }
                if (clips.isNotEmpty()) {
                    item { SectionHeader("Video") }
                    items(clips, key = { it.id }) { clip ->
                        ListItem(
                            headlineContent = { Text(clip.title) },
                            supportingContent = { Text(clip.durationLabel) },
                            leadingContent = {
                                Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Tokens.accent)
                            },
                            colors = ListItemDefaults.colors(
                                containerColor = MaterialTheme.colorScheme.surfaceContainer,
                            ),
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = Tokens.minTapTarget)
                                .clip(RoundedCornerShape(Tokens.radiusLg))
                                .clickable { onVideoClick(clip) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BoutRow(
    bout: BoutSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        ) {
            Text(
                bout.headline,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CornerLine(bout.red, bout, mode, slip, viewModel, Tokens.cornerRed)
            CornerLine(bout.blue, bout, mode, slip, viewModel, Tokens.cornerBlue)
            if (mode.showsResults) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = null,
                        tint = Tokens.positive,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(Tokens.spacingXs))
                    Text(
                        bout.resultLine,
                        style = MaterialTheme.typography.labelMedium,
                        color = Tokens.positive,
                    )
                }
            }
        }
    }
}

@Composable
private fun CornerLine(
    corner: CornerSummary,
    bout: BoutSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
    ring: Color,
) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
            FighterAvatar(viewModel.imageUrl(corner.portraitPath), ring, 40.dp)
            Spacer(Modifier.width(Tokens.spacingMd))
            Column {
                Text(corner.name, style = MaterialTheme.typography.bodyLarge)
                Text(
                    corner.recordDisplay,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (mode.showsOdds) {
            OddsChip(
                label = corner.oddsDecimal,
                selected = slip.selections.any {
                    it.boutId == bout.id && it.fighterId == corner.fighterId
                },
                onClick = {
                    viewModel.toggleSelection(bout, corner.fighterId, corner.oddsDecimal)
                },
            )
        }
    }
}

@Composable
private fun OddsChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val chipModifier = Modifier.defaultMinSize(minWidth = 64.dp, minHeight = Tokens.minTapTarget)
    val contentPadding = PaddingValues(horizontal = Tokens.spacingMd)
    if (selected) {
        Button(
            onClick = onClick,
            shape = RoundedCornerShape(Tokens.radiusMd),
            modifier = chipModifier,
            contentPadding = contentPadding,
        ) {
            Text(label, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        }
    } else {
        FilledTonalButton(
            onClick = onClick,
            shape = RoundedCornerShape(Tokens.radiusMd),
            modifier = chipModifier,
            contentPadding = contentPadding,
        ) {
            Text(
                label,
                fontWeight = FontWeight.SemiBold,
                color = Tokens.accent,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
internal fun BoutDetailScreen(
    bout: BoutSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
    balance: String,
    onDeposit: () -> Unit,
    onFighterClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(
        title = bout.weightClassDisplay,
        onBack = onBack,
        balance = balance,
        onDeposit = onDeposit,
    ) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                start = Tokens.spacingLg,
                end = Tokens.spacingLg,
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingLg),
        ) {
            item {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = Tokens.spacingLg),
                    verticalAlignment = Alignment.Top,
                ) {
                    FighterHero(bout.red, Tokens.cornerRed, viewModel, onFighterClick, Modifier.weight(1f))
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(top = Tokens.spacingXl),
                    ) {
                        Text(
                            "VS",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        if (bout.titleFight) {
                            Icon(Icons.Default.Star, contentDescription = null, tint = Tokens.accent)
                        }
                    }
                    FighterHero(bout.blue, Tokens.cornerBlue, viewModel, onFighterClick, Modifier.weight(1f))
                }
            }
            item { SectionHeader("Tale of the tape") }
            item { TaleOfTheTape(bout.id, viewModel.requireCatalog()) }
            if (mode.showsOdds) {
                item { SectionHeader("Outright winner") }
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(
                            Modifier.padding(Tokens.spacingLg),
                            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
                        ) {
                            CornerLine(bout.red, bout, mode, slip, viewModel, Tokens.cornerRed)
                            CornerLine(bout.blue, bout, mode, slip, viewModel, Tokens.cornerBlue)
                        }
                    }
                }
            }
            if (mode.showsResults) {
                item { SectionHeader("Result") }
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(Modifier.padding(Tokens.spacingLg)) {
                            DetailRow("Winner", bout.winnerName, Tokens.positive)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Method", bout.resultMethod.displayMethod)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Detail", bout.resultDetail)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Ended", "Round ${bout.endRound} · ${bout.endTime}")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FighterHero(
    corner: CornerSummary,
    ring: Color,
    viewModel: MainViewModel,
    onClick: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = Tokens.minTapTarget)
            .clickable { onClick(corner.fighterId) },
    ) {
        FighterAvatar(viewModel.imageUrl(corner.portraitPath), ring, 88.dp)
        Text(
            corner.name,
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            corner.recordDisplay,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun TaleOfTheTape(boutId: String, catalog: EventCatalog) {
    val tape = runCatching { catalog.taleOfTheTape(boutId) }.getOrNull()

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            tape?.rows?.forEach { TapeRow(it.red, it.label, it.blue) }
            tape?.edgeSummary?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/**
 * Weighted columns rather than [Arrangement.SpaceBetween]: space-between distributes the slack
 * between three texts of different widths, so no two rows lined up with each other.
 */
@Composable
private fun TapeRow(left: String?, label: String, right: String?) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            left ?: "—",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Start,
            softWrap = true,
            maxLines = 2,
            overflow = TextOverflow.Visible,
            modifier = Modifier.weight(1f),
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(80.dp),
        )
        Text(
            right ?: "—",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.End,
            softWrap = true,
            maxLines = 2,
            overflow = TextOverflow.Visible,
            modifier = Modifier.weight(1f),
        )
    }
}
