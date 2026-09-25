package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.fightdeck.baseline.ui.MainViewModel

// The SDK screens the `both` flavour does not link, as placeholders. The ones it does link come
// from android/app/src/all/sdk, the same files the demo app compiles.

@Composable
fun FighterSdkScreen(
    fighter: fight.deck.core.Fighter,
    viewModel: MainViewModel,
    saveKey: String,
    modifier: Modifier = Modifier,
) {
    UnavailableFeature("Fighter profile (both-only build)", modifier)
}

@Composable
private fun UnavailableFeature(label: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
