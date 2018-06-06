using Iscalc
using Plots
#plotlyjs()
#gr()
plotly()

#Svensson = JuliaDB.load("C:/Users/António/Desktop/BaseDados/Svensson_2018-05-26.jdb")
Svensson = obter(:NSS, inicio = "01-01-2000", fim = "28-05-2018")
show(IOContext(STDOUT, limit=true), "text/plain", Svensson)

DataReferencia = Date("2018-05-28")

Portfolio = ["PTOTESOE0013"  "2022-10-17"    0.02200  	 107.63;
             "PTOTEKOE0011"	 "2025-10-15"	 0.02875	 111.03;
             "PTOTETOE0012"	 "2026-07-21"	 0.02875	 109.56;
             "PTOTEUOE0019"	 "2027-04-14"	 0.04125	 118.90;
             "PTOTEROE0014"	 "2030-02-15"	 0.03875	 117.60]

# Juros Corridos das Obrigações
JC = JCorridos(Portfolio,DataReferencia)
println(JC)

# Tenores e Respectivos Fluxos de Caixa
TFC = FluxosCaixa(Portfolio,DataReferencia)
println(TFC)

Tenores = column(TFC,:Tenores)
FC = column(TFC,:FluxosCaixa)

# Estrutura Temporal Taxas de Juro: Curva Spot 

FS = fspot(Svensson, Tenores)
printm(FS)


# Gráfico da ETTJ para a data mais recente
plot(Tenores,FS[1,2:end], ylims = (-1,1), ylabel="ETTJ Taxas Spot", xlims = (0, 12.5), xlabel = "Tenores", label="$(FS[1,1])")
gui()

# Estrutura Temporal Taxas de Juro: Função Desconto
FD = fdesconto(Svensson, Tenores)
printm(FD)

#VPortfolio = table(FD[:,1], FD[:,2:(length(Tenores)+1)] * FC, names=[:Data,:Vp])


VPortfolio = hcat(FD[:,1], FD[:,2:end] * FC)
printm(VPortfolio)

c = VPortfolio[:,2] .-lag(VPortfolio[:,2],-1)

media = mean(c[1:end-1])
quantil05 = quantile(convert(Array{Float64},c[1:end-1]), 0.05)

c = hcat(FD[:,1],c)
printm(c)

VaR_05 = media - quantil05
println("VaR_5% = ", VaR_05)
