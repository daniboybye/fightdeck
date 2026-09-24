package com.fightdeck.rn.runtime

import android.content.Context
import android.os.Bundle
import android.view.View

/**
 * What every feature adapter shares: the React module it renders and the parameters it pushed
 * last. A feature adds its field-by-field marshalling and, if it reports back, its result handler.
 */
abstract class FeatureAdapter<P>(private val moduleName: String) {
    private var lastPushed: P? = null

    protected abstract fun propsBundle(params: P): Bundle

    fun createView(context: Context, params: P): View {
        lastPushed = params
        return FightDeckRNRuntime.createSurfaceView(context, moduleName, propsBundle(params))
    }

    /** Only a change reaches React: new props re-render the surface from its root. */
    fun updateProps(hostView: View, params: P) {
        if (params == lastPushed) {
            return
        }
        lastPushed = params
        FightDeckRNRuntime.updateSurfaceProps(hostView, propsBundle(params))
    }
}
