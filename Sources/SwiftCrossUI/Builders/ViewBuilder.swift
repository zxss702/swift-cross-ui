// This file was generated using gyb. Do not edit it directly. Edit
// ViewBuilder.swift.gyb instead.

// swiftformat:options --allow-partial-wrapping true

/// A result builder used to compose views together into composite views in
/// a declarative manner.
@resultBuilder
public struct ViewBuilder {
    public static func buildBlock() -> some View {
        return EmptyView()
    }

    public static func buildBlock<
        V0: View
    >(
        _ view0: V0
    ) -> V0 {
        return view0
    }

    public static func buildBlock<
        V0: View, V1: View
    >(
        _ view0: V0, _ view1: V1
    ) -> TupleView2<
        V0, V1
    > {
        return TupleView2<
        V0, V1
    >(view0, view1)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2
    ) -> TupleView3<
        V0, V1, V2
    > {
        return TupleView3<
        V0, V1, V2
    >(view0, view1, view2)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3
    ) -> TupleView4<
        V0, V1, V2, V3
    > {
        return TupleView4<
        V0, V1, V2, V3
    >(view0, view1, view2, view3)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4
    ) -> TupleView5<
        V0, V1, V2, V3, V4
    > {
        return TupleView5<
        V0, V1, V2, V3, V4
    >(view0, view1, view2, view3, view4)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5
    ) -> TupleView6<
        V0, V1, V2, V3, V4, V5
    > {
        return TupleView6<
        V0, V1, V2, V3, V4, V5
    >(view0, view1, view2, view3, view4, view5)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6
    ) -> TupleView7<
        V0, V1, V2, V3, V4, V5, V6
    > {
        return TupleView7<
        V0, V1, V2, V3, V4, V5, V6
    >(view0, view1, view2, view3, view4, view5, view6)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7
    ) -> TupleView8<
        V0, V1, V2, V3, V4, V5, V6, V7
    > {
        return TupleView8<
        V0, V1, V2, V3, V4, V5, V6, V7
    >(view0, view1, view2, view3, view4, view5, view6, view7)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8
    ) -> TupleView9<
        V0, V1, V2, V3, V4, V5, V6, V7, V8
    > {
        return TupleView9<
        V0, V1, V2, V3, V4, V5, V6, V7, V8
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9
    ) -> TupleView10<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9
    > {
        return TupleView10<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10
    ) -> TupleView11<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10
    > {
        return TupleView11<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11
    ) -> TupleView12<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11
    > {
        return TupleView12<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12
    ) -> TupleView13<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12
    > {
        return TupleView13<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13
    ) -> TupleView14<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13
    > {
        return TupleView14<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14
    ) -> TupleView15<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14
    > {
        return TupleView15<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15
    ) -> TupleView16<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15
    > {
        return TupleView16<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16
    ) -> TupleView17<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16
    > {
        return TupleView17<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17
    ) -> TupleView18<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17
    > {
        return TupleView18<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18
    ) -> TupleView19<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18
    > {
        return TupleView19<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19
    ) -> TupleView20<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19
    > {
        return TupleView20<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20
    ) -> TupleView21<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20
    > {
        return TupleView21<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21
    ) -> TupleView22<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21
    > {
        return TupleView22<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22
    ) -> TupleView23<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22
    > {
        return TupleView23<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23
    ) -> TupleView24<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23
    > {
        return TupleView24<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24
    ) -> TupleView25<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24
    > {
        return TupleView25<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View, V25: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24, _ view25: V25
    ) -> TupleView26<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25
    > {
        return TupleView26<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24, view25)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View, V25: View, V26: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24, _ view25: V25, _ view26: V26
    ) -> TupleView27<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26
    > {
        return TupleView27<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24, view25, view26)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View, V25: View, V26: View, V27: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24, _ view25: V25, _ view26: V26, _ view27: V27
    ) -> TupleView28<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27
    > {
        return TupleView28<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24, view25, view26, view27)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View, V25: View, V26: View, V27: View, V28: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24, _ view25: V25, _ view26: V26, _ view27: V27, _ view28: V28
    ) -> TupleView29<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28
    > {
        return TupleView29<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24, view25, view26, view27, view28)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View, V25: View, V26: View, V27: View, V28: View, V29: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24, _ view25: V25, _ view26: V26, _ view27: V27, _ view28: V28, _ view29: V29
    ) -> TupleView30<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29
    > {
        return TupleView30<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24, view25, view26, view27, view28, view29)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View, V25: View, V26: View, V27: View, V28: View, V29: View, V30: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24, _ view25: V25, _ view26: V26, _ view27: V27, _ view28: V28, _ view29: V29, _ view30: V30
    ) -> TupleView31<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29, V30
    > {
        return TupleView31<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29, V30
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24, view25, view26, view27, view28, view29, view30)
    }

    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View, V15: View, V16: View, V17: View, V18: View, V19: View, V20: View, V21: View, V22: View, V23: View, V24: View, V25: View, V26: View, V27: View, V28: View, V29: View, V30: View, V31: View
    >(
        _ view0: V0, _ view1: V1, _ view2: V2, _ view3: V3, _ view4: V4, _ view5: V5, _ view6: V6, _ view7: V7, _ view8: V8, _ view9: V9, _ view10: V10, _ view11: V11, _ view12: V12, _ view13: V13, _ view14: V14, _ view15: V15, _ view16: V16, _ view17: V17, _ view18: V18, _ view19: V19, _ view20: V20, _ view21: V21, _ view22: V22, _ view23: V23, _ view24: V24, _ view25: V25, _ view26: V26, _ view27: V27, _ view28: V28, _ view29: V29, _ view30: V30, _ view31: V31
    ) -> TupleView32<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29, V30, V31
    > {
        return TupleView32<
        V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29, V30, V31
    >(view0, view1, view2, view3, view4, view5, view6, view7, view8, view9, view10, view11, view12, view13, view14, view15, view16, view17, view18, view19, view20, view21, view22, view23, view24, view25, view26, view27, view28, view29, view30, view31)
    }

    public static func buildEither<A: View, B: View>(first component: A) -> EitherView<A, B> {
        return EitherView(component)
    }

    public static func buildEither<A: View, B: View>(second component: B) -> EitherView<A, B> {
        return EitherView(component)
    }

    public static func buildIf<V: View>(_ content: V?) -> OptionalView<V> {
        return OptionalView(content)
    }
}
