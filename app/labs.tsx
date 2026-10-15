"use client";
import { useState } from "react";
const fmt = (n: number) =>
  n.toLocaleString(undefined, { maximumFractionDigits: 2 });
export default function Labs({ initial = "parameters" }: { initial?: string }) {
  const [tab, T] = useState(initial),
    [billions, B] = useState(10),
    [bits, S] = useState(16),
    [lr, L] = useState(0.1),
    [step, U] = useState(0),
    [weight, W] = useState(4),
    [risk, R] = useState(1),
    [trades, N] = useState(10),
    [rate, Y] = useState(6),
    [leak, K] = useState(false),
    [temperature, H] = useState(1);
  const [running, A] = useState(false);
  const keys = [
    "parameters",
    "gradient",
    "attention",
    "leakage",
    "risk",
    "bonds",
  ];
  const logits = [1, 2, 3],
    probs = logits.map((x) => Math.exp(x / temperature));
  const sum = probs.reduce((a, b) => a + b, 0);
  const price =
    Array.from(
      { length: 5 },
      (_, i) => 60 / Math.pow(1 + rate / 100, i + 1),
    ).reduce((a, b) => a + b, 0) +
    1000 / Math.pow(1 + rate / 100, 5);
  function advance() {
    W((w) => w - lr * 2 * (w - 1));
    U((s) => s + 1);
  }
  return (
    <div className="labs">
      <div className="chips">
        {keys.map((k) => (
          <button
            key={k}
            className={k === tab ? "active" : ""}
            onClick={() => T(k)}
          >
            {k}
          </button>
        ))}
      </div>
      {tab === "parameters" && (
        <>
          <h2>How large is a billion parameters?</h2>
          <p>
            A parameter is a learned scalar, such as one weight in a matrix. It
            is not a fact, neuron, or token. These are idealized weight-only
            decimal GB, not a hardware recommendation.
          </p>
          <label>
            Parameters: {billions} billion
            <input
              aria-label="Billions of parameters"
              type="range"
              min="1"
              max="120"
              value={billions}
              onChange={(e) => B(+e.target.value)}
            />
          </label>
          <div className="chips">
            {[4, 8, 16, 32].map((n) => (
              <button
                className={bits === n ? "active" : ""}
                key={n}
                onClick={() => S(n)}
              >
                {n} bit
              </button>
            ))}
            <button onClick={() => B(10)}>10B</button>
            <button onClick={() => B(113)}>113B</button>
          </div>
          <div className="big-number">
            {fmt((billions * bits) / 8)} <small>GB of raw weights</small>
          </div>
          <div className="bar">
            <span
              style={{
                width: Math.min(100, ((billions * bits) / 8 / 480) * 100) + "%",
              }}
            />
          </div>
          <p className="formula">N × bits ÷ 8 bytes · 10B × 16 ÷ 8 = 20 GB</p>
          <p>
            Training also needs gradients, optimizer state, activations and
            temporary buffers. Inference adds KV cache and runtime overhead.
            Quantization uses scales and metadata; 4-bit storage is not exactly
            4 bits per parameter end to end. Mixture-of-experts total parameters
            differ from parameters activated per token.
          </p>
        </>
      )}
      {tab === "gradient" && (
        <>
          <h2>Watch gradient descent</h2>
          <p>
            For L(w) = (w − 1)², the derivative is 2(w − 1). Each step subtracts
            learning rate × derivative. The minimum is w = 1.
          </p>
          <label>
            Learning rate: {lr.toFixed(2)}
            <input
              aria-label="Learning rate"
              type="range"
              min=".01"
              max="1.2"
              step=".01"
              value={lr}
              onChange={(e) => L(+e.target.value)}
            />
          </label>
          <svg
            viewBox="0 0 600 230"
            role="img"
            aria-label="Quadratic loss curve with current weight"
          >
            <path
              d="M40 20 Q300 400 560 20"
              fill="none"
              stroke="#b1c5b5"
              strokeWidth="4"
            />
            <line x1="300" y1="20" x2="300" y2="225" stroke="#d7ded2" />
            <circle
              cx={Math.max(15, Math.min(585, 300 + (weight - 1) * 65))}
              cy={Math.max(15, 210 - Math.pow(weight - 1, 2) * 11.875)}
              r="9"
              fill="#bb5b3f"
            />
            <text x="310" y="220">
              minimum
            </text>
          </svg>
          <p className="formula">
            Step {step}: w = {fmt(weight)} · loss = {fmt((weight - 1) ** 2)}
          </p>
          <div className="chips">
            <button onClick={advance}>Take a step</button>
            <button
              disabled={running}
              onClick={() => {
                A(true);
                let n = 0;
                const timer = setInterval(() => {
                  advance();
                  if (++n === 8) {
                    clearInterval(timer);
                    A(false);
                  }
                }, 180);
              }}
            >
              Animate 8 steps
            </button>
            <button
              onClick={() => {
                W(4);
                U(0);
              }}
            >
              Reset
            </button>
          </div>
          <p>
            Try 0.1, 0.8, then 1.1. Large steps can oscillate and diverge. The
            dot clips at the drawing boundary; the numerical loss remains
            authoritative. Real neural loss landscapes are not this convex bowl.
          </p>
        </>
      )}
      {tab === "attention" && (
        <>
          <h2>Attention as weighted information</h2>
          <p>
            Three illustrative key scores are [1, 2, 3]. Softmax normalizes
            their exponentials. Temperature here is an educational control on
            these scores, not the output sampling temperature of an LLM.
          </p>
          <label>
            Score temperature: {temperature.toFixed(1)}
            <input
              aria-label="Attention temperature"
              type="range"
              min=".2"
              max="3"
              step=".1"
              value={temperature}
              onChange={(e) => H(+e.target.value)}
            />
          </label>
          {probs.map((p, i) => (
            <div key={i} className="attention-row">
              <span>Key {i + 1}</span>
              <div className="bar">
                <span style={{ width: (p / sum) * 100 + "%" }} />
              </div>
              <strong>{((p / sum) * 100).toFixed(1)}%</strong>
            </div>
          ))}
          <p className="formula">
            Attention(Q,K,V) = softmax(QKᵀ / √dₖ + mask) V
          </p>
          <p>
            Weights sum to one over allowed keys. Causal masking excludes future
            tokens. These weights are not a reliable explanation of all the
            model’s reasoning.
          </p>
        </>
      )}
      {tab === "leakage" && (
        <>
          <h2>When was the information available?</h2>
          <p>
            A prediction is made at 10:00. A candle closing at 10:05 cannot be a
            feature for that prediction, even if its label says “10:00 candle”.
          </p>
          <button className={leak ? "danger" : ""} onClick={() => K(!leak)}>
            {leak
              ? "Remove future-close feature"
              : "Include future-close feature"}
          </button>
          <div className="timeline">
            {["09:55 close known", "10:00 decision", "10:05 close known"].map(
              (x, i) => (
                <div key={x} className={i === 2 && leak ? "invalid" : ""}>
                  <b>{i + 1}</b>
                  {x}
                </div>
              ),
            )}
          </div>
          <div className="callout">
            {leak
              ? "LEAKAGE: The decision depends on a future observation. A beautiful backtest cannot rescue it."
              : "CAUSAL: Only information available by the decision time can enter the feature vector."}
          </div>
          <p>
            Also audit publication delays, adjusted prices, changing index
            membership, revised fundamentals, labels spanning split boundaries
            and scalers fitted on the test set.
          </p>
        </>
      )}
      {tab === "risk" && (
        <>
          <h2>A losing streak changes the account</h2>
          <p>
            Illustrative fixed-fraction losses from ₹10,000, before costs. This
            is a scenario, not a probability model or return forecast.
          </p>
          <label>
            Risk per trade: {risk}%
            <input
              aria-label="Risk percentage"
              type="range"
              min=".25"
              max="10"
              step=".25"
              value={risk}
              onChange={(e) => R(+e.target.value)}
            />
          </label>
          <label>
            Consecutive losses: {trades}
            <input
              aria-label="Consecutive losses"
              type="range"
              min="1"
              max="30"
              value={trades}
              onChange={(e) => N(+e.target.value)}
            />
          </label>
          <div className="big-number">
            ₹{fmt(10000 * (1 - risk / 100) ** trades)}
          </div>
          <p>
            Drawdown: {fmt((1 - (1 - risk / 100) ** trades) * 100)}%. Recovery
            needed: {fmt(((1 - risk / 100) ** -trades - 1) * 100)}%.
          </p>
          <div className="bar">
            <span style={{ width: (1 - risk / 100) ** trades * 100 + "%" }} />
          </div>
          <p>
            Stops do not guarantee fills at their trigger price. Costs,
            slippage, leverage and gaps can produce larger losses. “2:1
            reward–risk” describes planned payoff, not the chance of winning.
          </p>
        </>
      )}
      {tab === "bonds" && (
        <>
          <h2>Rates up, fixed bond price down</h2>
          <p>
            A five-year bond pays ₹60 annually and returns ₹1,000 at maturity.
            Assume annual compounding, no default and no accrued interest.
          </p>
          <label>
            Yield: {rate}%
            <input
              aria-label="Bond yield"
              type="range"
              min="0"
              max="15"
              step=".25"
              value={rate}
              onChange={(e) => Y(+e.target.value)}
            />
          </label>
          <div className="big-number">₹{fmt(price)}</div>
          <p className="formula">P = Σₜ₌₁⁵ 60/(1+y)ᵗ + 1,000/(1+y)⁵</p>
          <div className="bar">
            <span style={{ width: (price / 1300) * 100 + "%" }} />
          </div>
          <p>
            At a 6% yield, the bond trades at par. Duration approximates
            sensitivity to small parallel yield changes; convexity improves the
            approximation. Credit spreads and liquidity also move real bond
            prices.
          </p>
        </>
      )}
    </div>
  );
}
