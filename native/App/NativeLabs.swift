import SwiftUI
import Charts
import AcademyCore
struct NativeLabs:View {
    @State var selected:String
    @State var billions=10.0
    @State var bits=16.0
    @State var rate=0.1
    @State var weight=4.0
    @State var temperature=1.0
    @State var risk=1.0
    @State var losses=10.0
    @State var yield=6.0
    @State var steps=0
    @State var leaked=false
    @State var animation:Task<Void,Never>?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    init(initial:String="parameters"){_selected=State(initialValue:initial)}
    let names=["parameters","gradient","attention","leakage","risk","bonds"]
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                PageTitle(eyebrow:"Predict · adjust · observe",title:"Make the idea visible.",subtitle:"Small deterministic teaching models, not trading signals.")
                Picker("Lab",selection:$selected){ForEach(names,id:\.self){Text($0.capitalized)}}.pickerStyle(.menu)
                AcademyCard {
                    switch selected {
                    case "parameters":
                        Text("How large is a billion parameters?").font(.title2)
                        Text("Parameters are learned scalars, not facts or neurons. This is ideal weight-only storage in decimal GB.")
                        control("Parameters: \(Int(billions)) billion",value:$billions,range:1...120,step:1)
                        Picker("Precision",selection:$bits){ForEach([4.0,8,16,32],id:\.self){Text("\(Int($0)) bit")}}.pickerStyle(.segmented)
                        HStack{Button("10B"){billions=10};Button("113B"){billions=113}}.buttonStyle(.bordered)
                        number(LabMath.weightGB(billions:billions,bits:bits),"GB of raw weights")
                        Text("N × bits ÷ 8 bytes. Training adds gradients, optimizer state and activations. Inference adds KV cache and runtime overhead. Quantized formats also need metadata.").foregroundStyle(.secondary)
                    case "gradient":
                        Text("Watch gradient descent").font(.title2)
                        Text("L(w) = (w − 1)². Subtract learning rate × 2(w − 1) each step.")
                        control("Learning rate: "+rate.formatted(),value:$rate,range:0.01...1.2,step:0.01)
                        Chart {
                            ForEach(0...80,id:\.self){i in
                                let x=Double(i)/10-3
                                LineMark(x:.value("Weight",x),y:.value("Loss",pow(x-1,2))).foregroundStyle(Color.academyAccent)
                            }
                            PointMark(x:.value("Weight",max(-3,min(5,weight))),y:.value("Loss",min(16,pow(weight-1,2)))).foregroundStyle(.orange)
                        }.chartXScale(domain:-3...5).chartYScale(domain:0...16).frame(height:220)
                        Text("Step \(steps): w = \(weight.formatted()), loss = \(pow(weight-1,2).formatted())").monospacedDigit()
                        HStack {
                            Button("Take a step"){step()}
                            Button("8 steps"){animation?.cancel();animation=Task{for _ in 0..<8{if Task.isCancelled{return};step();try? await Task.sleep(for:.milliseconds(reduceMotion ? 0:200))}}}
                            Button("Reset"){animation?.cancel();weight=4;steps=0}
                        }.buttonStyle(.bordered)
                        Text("Try 0.1, then 1.1. Large steps can diverge. The point clips at chart limits; numeric loss is authoritative.").font(.caption).foregroundStyle(.secondary)
                    case "attention":
                        Text("Attention as weighted information").font(.title2)
                        Text("Scores [1,2,3] become normalized positive weights. This score temperature is not output-token sampling temperature.")
                        control("Score temperature: "+temperature.formatted(),value:$temperature,range:0.2...3,step:0.1)
                        Chart {
                            ForEach(Array(LabMath.attention(temperature:temperature).enumerated()),id:\.offset){i,v in BarMark(x:.value("Weight",v),y:.value("Key","Key \(i+1)")).foregroundStyle(Color.academyAccent)}
                        }.chartXScale(domain:0...1).frame(height:180)
                        Text("softmax(QKᵀ / √dₖ + mask) V").font(.system(.body,design:.monospaced))
                        Text("Causal masking excludes future tokens. Attention weights alone are not a reliable explanation of reasoning.").font(.caption).foregroundStyle(.secondary)
                    case "leakage":
                        Text("When was the information available?").font(.title2)
                        Text("A prediction made at 10:00 cannot use a candle closing at 10:05, even if its label says 10:00.")
                        Toggle("Include the future close",isOn:$leaked)
                        ForEach(["09:55 · previous close known","10:00 · decision","10:05 · next close known"],id:\.self){Text($0).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Color.academyPaper,in:RoundedRectangle(cornerRadius:8))}
                        Label(leaked ? "Leakage: the decision sees the future." : "Causal: use information already available.",systemImage:leaked ? "exclamationmark.triangle" : "checkmark.shield").font(.headline)
                        Text("Also audit revisions, publication delays, label overlap and preprocessing fitted on test data.").font(.caption)
                    case "risk":
                        Text("A losing streak changes the account").font(.title2)
                        Text("₹10,000 with fixed-fraction losses, before costs. A scenario, not a forecast.")
                        control("Risk per trade: "+risk.formatted()+"%",value:$risk,range:0.25...10,step:0.25)
                        control("Consecutive losses: \(Int(losses))",value:$losses,range:1...30,step:1)
                        let capital=LabMath.capital(riskPercent:risk,losses:Int(losses))
                        number(capital,"rupees remaining")
                        ProgressView(value:capital,total:10000)
                        Text("Drawdown: \(((1-capital/10000)*100).formatted(.number.precision(.fractionLength(1))))%. Recovery needed: \(((10000/capital-1)*100).formatted(.number.precision(.fractionLength(1))))%.")
                        Text("Stops do not guarantee fills. A 2:1 target does not specify the chance of winning.").font(.caption)
                    default:
                        Text("Rates up, fixed bond price down").font(.title2)
                        Text("Five years, ₹60 annual coupon, ₹1,000 principal. Annual compounding, no default or accrued interest.")
                        control("Yield: "+yield.formatted()+"%",value:$yield,range:0...15,step:0.25)
                        number(LabMath.bondPrice(yield:yield),"rupees · present value")
                        Text("P = Σ 60/(1+y)ᵗ + 1,000/(1+y)⁵").font(.system(.body,design:.monospaced))
                        Text("At 6% yield the bond is at par. Duration approximates small parallel rate changes; convexity improves it.").font(.caption)
                    }
                }
            }.padding(24).frame(maxWidth:850)
        }.frame(maxWidth:.infinity).background(Color.academyPaper).onDisappear{animation?.cancel()}.onChange(of:selected){_,_ in animation?.cancel()}
    }
    func step(){weight=LabMath.gradientStep(weight:weight,rate:rate);steps+=1}
    func control(_ title:String,value:Binding<Double>,range:ClosedRange<Double>,step:Double)->some View{VStack(alignment:.leading){Text(title).font(.subheadline);Slider(value:value,in:range,step:step).accessibilityLabel(title)}}
    func number(_ value:Double,_ label:String)->some View{VStack(alignment:.leading){Text(value.formatted(.number.precision(.fractionLength(0...2)))).font(.system(.largeTitle,design:.serif));Text(label).font(.caption).foregroundStyle(.secondary)}}
}
