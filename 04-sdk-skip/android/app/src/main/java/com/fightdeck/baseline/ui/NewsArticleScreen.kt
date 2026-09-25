package com.fightdeck.baseline.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fightdeck.baseline.design.Tokens
import fight.deck.events.MediaItem
import fight.deck.events.NewsItem
import java.math.BigDecimal

@Composable
internal fun NewsArticleScreen(
    item: NewsItem,
    media: List<MediaItem>,
    viewModel: MainViewModel,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = "Article", onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
        ) {
            item {
                RemoteImage(
                    url = viewModel.imageUrl(item.heroImage),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp),
                )
            }
            item {
                Column(
                    Modifier.padding(Tokens.spacingLg),
                    verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
                ) {
                    Text(item.headline, style = MaterialTheme.typography.headlineSmall)
                    Text(
                        "${item.readMinutes} min read · ${item.source}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(item.body, style = MaterialTheme.typography.bodyLarge)
                }
            }
            val clips = media.filter { it.eventId == item.eventId }
            if (clips.isNotEmpty()) {
                item {
                    SectionHeader("Watch", Modifier.padding(horizontal = Tokens.spacingLg))
                }
                items(clips, key = { it.id }) { clip ->
                    ListItem(
                        headlineContent = { Text(clip.title) },
                        leadingContent = {
                            Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Tokens.accent)
                        },
                        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = Tokens.minTapTarget)
                            .clickable { onVideoClick(clip) },
                    )
                }
            }
        }
    }
}
