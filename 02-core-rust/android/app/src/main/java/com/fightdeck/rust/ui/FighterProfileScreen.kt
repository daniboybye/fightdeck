package com.fightdeck.rust.ui

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
import com.fightdeck.rust.design.Tokens
import uniffi.fightevents.FighterSummary

@Composable
internal fun FighterProfileScreen(
    fighter: FighterSummary,
    viewModel: MainViewModel,
    balance: String,
    onDeposit: () -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = fighter.name, onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
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
                        fighter.nickname?.let {
                            Text(
                                "\u201C$it\u201D",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(
                            fighter.recordDisplay,
                            style = MaterialTheme.typography.titleSmall,
                            color = Tokens.accent,
                        )
                    }
                }
            }
            item {
                Column(Modifier.padding(Tokens.spacingLg)) {
                    SectionHeader("Profile")
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(Modifier.padding(Tokens.spacingLg)) {
                            DetailRow("Record", fighter.recordDisplay)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Wins", "${fighter.wins}")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Losses", "${fighter.losses}")
                        }
                    }
                    SectionHeader("Physicals")
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(Modifier.padding(Tokens.spacingLg)) {
                            DetailRow("Height", fighter.heightCm?.let { "$it cm" } ?: "—")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Reach", fighter.reachIn?.let { "$it in" } ?: "—")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Stance", fighter.stance ?: "—")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Country", fighter.country ?: "—")
                        }
                    }
                }
            }
        }
    }
}
