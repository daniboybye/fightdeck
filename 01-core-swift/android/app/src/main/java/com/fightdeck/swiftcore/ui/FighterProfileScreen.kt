package com.fightdeck.swiftcore.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fightdeck.swiftcore.catalog.FighterCard
import com.fightdeck.swiftcore.design.Tokens

@Composable
internal fun FighterProfileScreen(
    fighter: FighterCard,
    viewModel: MainViewModel,
    balanceLabel: String,
    onDeposit: () -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = fighter.name, onBack = onBack, balanceLabel = balanceLabel, onDeposit = onDeposit) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
        ) {
            item {
                Box {
                    RemoteImage(
                        url = viewModel.imageUrl(fighter.portraitPath),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(320.dp),
                    )
                    Column(
                        Modifier
                            .align(Alignment.BottomStart)
                            .fillMaxWidth()
                            .background(
                                Brush.verticalGradient(
                                    listOf(Color.Transparent, Color.Black.copy(alpha = 0.75f)),
                                ),
                            )
                            .padding(Tokens.spacingLg),
                        verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs),
                    ) {
                        Text(fighter.name, style = MaterialTheme.typography.headlineLarge)
                        fighter.nickname?.let { nickname ->
                            Text(
                                "\u201C$nickname\u201D",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(
                            fighter.record,
                            style = MaterialTheme.typography.titleSmall,
                            color = Tokens.accent,
                        )
                    }
                }
            }
            item {
                Column(Modifier.padding(Tokens.spacingLg)) {
                    SectionHeader("Profile")
                    DetailCard(fighter.profileRows)
                    if (fighter.physicalRows.isNotEmpty()) {
                        SectionHeader("Physicals")
                        DetailCard(fighter.physicalRows)
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailCard(rows: List<Pair<String, String>>) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(Modifier.padding(Tokens.spacingLg)) {
            rows.forEachIndexed { index, (label, value) ->
                if (index > 0) {
                    HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                }
                DetailRow(label, value)
            }
        }
    }
}
