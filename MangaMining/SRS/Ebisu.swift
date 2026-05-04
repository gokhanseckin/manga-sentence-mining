import Foundation

struct EbisuModel: Sendable, Equatable {
    var alpha: Double
    var beta: Double
    var tHours: Double
}

/// Ebisu v2 Bayesian SRS — Beta prior on recall probability at horizon `t`,
/// closed-form posterior update on binary outcomes via moment matching against
/// the GB1 distribution. See https://fasiha.github.io/ebisu/ for the derivation.
enum Ebisu {
    /// Expected probability of recall at `elapsedHours` since the last review.
    static func predictRecall(model: EbisuModel, elapsedHours: Double) -> Double {
        let dt = elapsedHours / model.tHours
        let logRet = betaln(model.alpha + dt, model.beta) - betaln(model.alpha, model.beta)
        let p = exp(logRet)
        return min(max(p, 0), 1)
    }

    /// Posterior update on a binary observation. Returns the new model with its
    /// time horizon set to the just-elapsed interval (the natural moment-matched
    /// horizon for the new Beta posterior).
    static func updateRecall(model: EbisuModel, wasCorrect: Bool, elapsedHours: Double) -> EbisuModel {
        let dt = max(elapsedHours / model.tHours, 1e-9)
        let a = model.alpha
        let b = model.beta

        let m1: Double
        let m2: Double
        if wasCorrect {
            // posterior ∝ p^dt * Beta(a, b) → moments
            let l0 = betaln(a + dt, b)
            let l1 = betaln(a + dt + 1, b)
            let l2 = betaln(a + dt + 2, b)
            m1 = exp(l1 - l0)
            m2 = exp(l2 - l0)
        } else {
            // posterior ∝ (1 - p^dt) * Beta(a, b)
            let denom = logSubExp(betaln(a, b), betaln(a + dt, b))
            let num1 = logSubExp(betaln(a + 1, b), betaln(a + dt + 1, b))
            let num2 = logSubExp(betaln(a + 2, b), betaln(a + dt + 2, b))
            m1 = exp(num1 - denom)
            m2 = exp(num2 - denom)
        }
        let variance = max(m2 - m1 * m1, 1e-12)
        let sumAB = m1 * (1 - m1) / variance - 1
        let aNew = max(sumAB * m1, 0.5)
        let bNew = max(sumAB * (1 - m1), 0.5)
        return EbisuModel(alpha: aNew, beta: bNew, tHours: max(elapsedHours, 1e-3))
    }

    /// Hours from "now" until the predicted recall decays to `percentile`
    /// (default 50%). Binary search on `predictRecall`. Used to materialize
    /// `nextReviewAt`.
    static func modelToPercentileDecay(model: EbisuModel, percentile: Double = 0.5) -> Double {
        var lo = 0.0
        var hi = model.tHours
        while predictRecall(model: model, elapsedHours: hi) > percentile {
            hi *= 2
            if hi > 1_000_000 { return hi } // ~114 years; avoid overflow
        }
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            if predictRecall(model: model, elapsedHours: mid) > percentile {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo + hi) / 2
    }

    // MARK: - Math helpers

    private static func betaln(_ a: Double, _ b: Double) -> Double {
        lgamma(a) + lgamma(b) - lgamma(a + b)
    }

    /// log(exp(big) - exp(small)), stable for big ≥ small.
    private static func logSubExp(_ big: Double, _ small: Double) -> Double {
        big + log1p(-exp(small - big))
    }
}
