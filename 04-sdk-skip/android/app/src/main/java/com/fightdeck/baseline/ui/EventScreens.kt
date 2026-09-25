package com.fightdeck.baseline.ui

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
import com.fightdeck.baseline.design.BalanceMenuAction
import com.fightdeck.baseline.design.Tokens
import fight.deck.core.BetSlip
import fight.deck.core.Bout
import fight.deck.core.Corner
import fight.deck.core.Event
import fight.deck.core.Fighter
import fight.deck.core.Money
import fight.deck.events.Display
import fight.deck.events.MediaItem
import fight.deck.events.NewsItem
import java.math.BigDecimal

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EventListScreen(
    state: LoadState<List<Event>>,
    news: LoadState<List<NewsItem>>,
    media: LoadState<List<MediaItem>>,
    mode: EventMode,
    viewModel: MainViewModel,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onRetry: () -> Unit,
    onEventClick: (Event) -> Unit,
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
                        balanceLabel = Money.formatCurrency(balance),
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
                        posterUrl = viewModel.imageUrl("assets/events/${event.id}.jpg"),
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
private fun EventCard(event: Event, mode: EventMode, posterUrl: String?, onClick: () -> Unit) {
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
                "${event.venue} · ${event.city}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${event.date.displayDate} · ${event.bouts.count} fights",
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
    event: Event,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
    media: LoadState<List<MediaItem>>,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onBoutClick: (Bout) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
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
            // Same grouping the iOS screen uses, from the same shared function — the card is
            // billed as Main Event / Main Card / Prelims, not as one flat list.
            Display.cardSections(for_ = event.bouts).forEach { section ->
                item { SectionHeader(section.title) }
                // The transpiled section holds a Skip Array; `items` wants a Kotlin List.
                items(section.bouts.toList(), key = { it.id }) { bout ->
                    BoutRow(bout, mode, slip, viewModel, fighters, onClick = { onBoutClick(bout) })
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
    bout: Bout,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
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
            val title = bout.weightClass.replace('_', ' ').uppercase() +
                if (bout.titleFight) " · TITLE" else ""
            Text(
                "$title · ${bout.scheduledRounds} RNDS",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CornerLine(bout.redCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerRed)
            CornerLine(bout.blueCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerBlue)
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
                        "${bout.result.winnerName} · ${bout.result.method.displayMethod} · " +
                            "R${bout.result.endRound} ${bout.result.endTime}",
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
    corner: Corner,
    bout: Bout,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
    ring: Color,
) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
            FighterAvatar(viewModel.imageUrl("assets/fighters/${corner.fighterId}.jpg"), ring, 40.dp)
            Spacer(Modifier.width(Tokens.spacingMd))
            Column {
                Text(corner.name, style = MaterialTheme.typography.bodyLarge)
                Text(
                    fighters.firstOrNull { it.id == corner.fighterId }?.record?.display ?: "—",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (mode.showsOdds) {
            OddsChip(
                label = corner.closingOdds.decimal,
                selected = slip.selections.any {
                    it.boutID == bout.id && it.fighterID == corner.fighterId
                },
                onClick = {
                    viewModel.slipStore.toggleSelection(
                        boutID = bout.id,
                        fighterID = corner.fighterId,
                        odds = Money.parse(corner.closingOdds.decimal),
                    )
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
    bout: Bout,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onFighterClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(
        title = bout.weightClass.displayMethod,
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
                    FighterHero(bout.redCorner, Tokens.cornerRed, viewModel, fighters, onFighterClick, Modifier.weight(1f))
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
                    FighterHero(bout.blueCorner, Tokens.cornerBlue, viewModel, fighters, onFighterClick, Modifier.weight(1f))
                }
            }
            item { SectionHeader("Tale of the tape") }
            item { TaleOfTheTape(bout, fighters) }
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
                            CornerLine(bout.redCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerRed)
                            CornerLine(bout.blueCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerBlue)
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
                            DetailRow("Winner", bout.result.winnerName, Tokens.positive)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Method", bout.result.method.displayMethod)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Detail", bout.result.detail)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Ended", "Round ${bout.result.endRound} · ${bout.result.endTime}")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FighterHero(
    corner: Corner,
    ring: Color,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
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
        FighterAvatar(viewModel.imageUrl("assets/fighters/${corner.fighterId}.jpg"), ring, 88.dp)
        Text(
            corner.name,
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            fighters.firstOrNull { it.id == corner.fighterId }?.record?.display ?: "—",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun TaleOfTheTape(bout: Bout, fighters: List<Fighter>) {
    fun of(id: String): Fighter? = fighters.firstOrNull { it.id == id }
    val red = of(bout.redCorner.fighterId)
    val blue = of(bout.blueCorner.fighterId)

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            TapeRow(red?.record?.display, "RECORD", blue?.record?.display)
            TapeRow(red?.heightCm?.let { "$it cm" }, "HEIGHT", blue?.heightCm?.let { "$it cm" })
            TapeRow(red?.reachIn?.let { "$it in" }, "REACH", blue?.reachIn?.let { "$it in" })
            TapeRow(red?.stance?.replaceFirstChar { it.uppercase() }, "STANCE", blue?.stance?.replaceFirstChar { it.uppercase() })
            TapeRow(red?.country, "COUNTRY", blue?.country)
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
