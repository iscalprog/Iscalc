using Base.Dates, Requests, JuliaDB, CSV, FileIO, DataFrames, TextParse, HTTP, SQLite, DataStreams
using Missings


const mercado2mic=Dict(
"Euronext Access Lisbon"=>"ENXL",
"Euronext Access Paris"=>"XMLI",
"Euronext Amsterdam"=>"XAMS",
"Euronext Amsterdam, Brussels"=>"XAMS",
"Euronext Amsterdam, Paris"=>"XAMS",
"Euronext Brussels"=>"XBRU",
"Euronext Expert Market"=>"VPXB",
"Euronext Growth Brussels"=>"ALXB",
"Euronext Growth Paris"=>"ALXP",
"Euronext Lisbon"=>"XLIS",
"Euronext Paris"=>"XPAR",
"Euronext Paris, Amsterdam"=>"XPAR"
)

const df1 = DateFormat("dd uuu yyyy");

# Download/Ler de URL Remoto/Ficheiro dados em formato CSV usando TextParse  
function download(fonte, delim = "," ; saltar=0, datatipo="y-m-d", header=true, na = [""]) 
    try
    if na == [""]
        return TextParse.csvread(
            fonte, 
            skiplines_begin = saltar,
            colparsers = [TextParse.DateTimeToken(Date, DateFormat(datatipo))],
            header_exists=header)
    else
        return TextParse.csvread(
            fonte,
            skiplines_begin = saltar,
            header_exists = header,
            colparsers = [TextParse.DateTimeToken(Date, DateFormat(datatipo)), TextParse.NAToken(TextParse.Numeric(Float64), nastrings = na)])
    end
    catch # catching ERROR: LoadError: BoundsError: attempt to access ""
        return 0
    end
end

#function juliadb(textp, colindex, colseries; nomes::Array{Symbol,1}=[:Data,:Serie])
#    return  table(textp[1][colindex], textp[1][colseries], names=nomes, pkey = (nomes[colindex]))
# end

 #Euro = [Nome1	ISIN2	Symbol3	Location4	Maturity5	TradingCurrency6	Abrir7	Máximo8	Mínimo9	Fecho10	LastDate11	TimeZone12	Quantidade13	Turnover14]

function catalogo(Bolsa, Instrumento, Local="")
    colunas = [:ISIN :Emissão :Mercado :Maturidade]
    if Bolsa == "Euronext"
        if Instrumento == "Bonds"
            fonte = conformar("Euronext_Bonds_EU_2018-05-06.csv")
            resp = TextParse.csvread(fonte,skiplines_begin=5)
            tabela = table(resp[1][2], resp[1][1],resp[1][3], resp[1][4],names=colunas)
            if Local == ""
                return tabela
            else
                return filter(y->y.Mercado=="$Bolsa $Local",tabela)
            end
        end
    end
end

function info(isin)
    a = catalogo("Euronext", "Bonds")
    b = filter(y->y.ISIN==isin,a)
    issuename = select(b,2)      # Nome Emissão
    mic  = select(b,3)      # Codigo do mercado:"ENXL","XMLI","XAMS","XAMS","XAMS","XBRU","VPXB","ALXB","ALXP","XLIS","XPAR","XPAR"
    maturidade = select(b,4)
    return issuename[1], mic[1], maturidade[1]
end


function euronextBonds(isin; inicio="1000-01-01",fim="3000-01-01")
    colunas = [:ISIN, :Emissão, :Mercado,:Maturidade,:Data,:Abertura,:Máximo,:Mínimo,:Fecho,:NTrades,:Turnover]
    tabela = JuliaDB.table(["-"])
    
    iniciounix = datetime2unix(DateTime(inicio))*1000
    fimunix = datetime2unix(DateTime(fim))*1000
    euronextlocal = info(isin)[2]
    mic = mercado2mic[euronextlocal]
    euronextURL = "https://www.euronext.com/nyx_eu_listings/price_chart/download_historical?typefile=csv&separator=point&mic=$(mic)&isin=$(isin)&namefile=Price_Data_Historical&from=$(iniciounix)&to=$(fimunix)"
    
    fonte = conformar(euronextURL)
    resp = download(fonte, saltar = 4, header = false)
    # Catching ERROR: LoadError: BoundsError: attempt to access "" at index [0]
    if resp == 0  
        return table([isin], [info(isin)[1]], [info(isin)[2]], [info(isin)[3]], [DataValues.DataValue{Date}()],[DataValues.DataValue{Float64}()],[DataValues.DataValue{Float64}()],[DataValues.DataValue{Float64}()],[DataValues.DataValue{Float64}()],[DataValues.DataValue{Int64}()], [DataValues.DataValue{Float64}()], names=colunas)
    end  
    len = length(resp[1][1])
    col_ISIN = fill(isin,(len,1)) # resp[1][1], surge como TextParse.StrRange
    col_Nome = fill(info(isin)[1],(len,1))
    col_Mercado = fill(info(isin)[2],(len,1))  # resp[1][2]
    col_Maturidade = fill(info(isin)[3],(len,1))

    tabela = table(col_ISIN,col_Nome,col_Mercado,col_Maturidade,resp[1][3],resp[1][4],resp[1][5],resp[1][6],resp[1][7],resp[1][9],resp[1][10],names=colunas)
    return tabela
end

function factsheet(isin,mic)
    nomes = [:ISIN, :MIC, :Activo, :Mercado, :Emitente, :País, :PreçoEmissão, :Denominação, :DataEmissão, :DataReembolso,:TipoReembolso,:NotaçãoPreço,:TipoCoupon,:TaxaCoupon,:FreqCoupon]
    url = "https://www.euronext.com/en/factsheet-ajax?instrument_id=$(isin)-$(mic)&instrument_type=bonds"
    resp = HTTP.request("GET",url)
    text = String(resp.body) 
    z = split(text,"<strong>")
    tabela = table([isin], [mic], names=[:ISIN, :MIC], pkey=:ISIN)
    lenz = length(z)
    j = 2
    for i in [2,3,5,7,8,9,10,11,12,14,23,24,25] 
        j = j+1
        q = split(z[i],"</strong>")
        qnovo = strip(q[1])
        if (j == 7) || (j==8) 
            if qnovo == "-"
                valor1 = [DataValues.DataValue{Float64}()] #Tb poderiamos usar missing
            else
                valor1 = [parse(Float64,String(qnovo))]
            end
            tabela = pushcol(tabela,nomes[j],valor1)
        elseif (j==9) || (j==10)
            if qnovo == "-"
                valor2 = [DataValues.DataValue{Date}()] #Tb poderiamos usar missing
            else
                valor2 = [Date(String(qnovo),df1)]
            end
            tabela = pushcol(tabela,nomes[j],valor2)
        else
            if qnovo == "-"
                valor3 = [DataValues.DataValue{String}()] #Tb poderiamos usar missing
            else
                valor3 = String[qnovo]
            end
            tabela = pushcol(tabela,nomes[j],valor3)
        end
    end
    return tabela
end