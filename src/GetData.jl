# Query Date Format = yyyy-mm-dd
# Freq = D
# Date Column Format = yyyy-mm-dd
# Header Row = 1
# Rows to Exclude = 0

#using Base.Dates, Requests, JuliaDB, CSV, FileIO, DataFrames, TextParse, HTTP, SQLite, DataStreams

const FXALL = [:AUD	:BGN	:BRL	:CAD	:CHF	:CNY	:CYP	:CZK	:DKK	:EEK	:GBP	:GRD	:HKD	:HRK	:HUF	:IDR	:ILS	:INR	:ISK	:JPY	:KRW	:LTL	:LVL	:MTL	:MXN	:MYR	:NOK	:NZD	:PHP	:PLN	:RON	:RUB	:SEK	:SGD	:SIT	:SKK	:THB	:TRY	:USD	:ZAR    :FX] 
const FXsimbolo = [:USD :JPY :GBP :CHF :HKD] 

const SVENSSON = [:BETA0, :BETA1, :BETA2, :BETA3, :TAU1, :TAU2]

const EURIBOR = [:EURIBOR1M, :EURIBOR3M, :EURIBOR6M, :EURIBOR9M, :EURIBOR1Y]

const MMIsimbolo = [:FD, :FME, :OPR, :EONIA]
const MMIcodigo = ["143.FM.D.U2.EUR.4F.KR.DFR.LEV", "143.FM.D.U2.EUR.4F.KR.MLFR.LEV", "143.FM.D.U2.EUR.4F.KR.MRR_FR.LEV", "198.EON.D.EONIA_TO.RATE"]

const RFRsimbolo = [:BE, :DE, :FR, :IT, :NL, :SP]
const RFRurl = ["RFR_Belgium.csv", "RFR_Germany.csv", "RFR_France.csv", "RFR_Italy.csv", "RFR_Netherlands.csv", "RFR_Spain.csv"]

const quandlheaders = [:ticker, :date, :open, :high, :low, :close, :volume, :ex_dividend, :split_ratio, :adj_open, :adj_high, :adj_low, :adj_close, :adj_volume]

function quandl(simbolos, inicio = "0001-01-01", fim = "9999-01-01") 
    quandltURL = "https://www.quandl.com/api/v3/datatables/WIKI/PRICES.csv?ticker=$(simbolos)&date.gte=$(inicio)&date.lte=$(fim)&api_key=DQw1bXYU8NieGQKTYnJy"
    fonte = conformar(quandltURL)
    resp = download(fonte)
    tabela = JuliaDB.table(resp[1]..., names = map(Symbol,resp[2]), pkey = (:ticker,:date))
end


function conformar(a::String)
    if a[1:4] == "http"
        return  IOBuffer(HTTP.get(a).body)
    else 
        return a
    end
end

# Download/Ler de URL Remoto/Ficheiro dados em formato CSV usando TextParse  
#function download(fonte, separador=','; saltar=0, datatipo="y-m-d", header=true, na = [""]) 
#    if na == [""]
#        return TextParse.csvread(fonte, separador, skiplines_begin = saltar,header_exists=header)
#    else
#        return TextParse.csvread(
#            fonte,
#            skiplines_begin = saltar,
#            header_exists = header,
#            colparsers = [TextParse.DateTimeToken(Date, DateFormat(datatipo)), TextParse.NAToken(TextParse.Numeric(Float64), nastrings = na)])
#    end
#end

# Ingerir dados obtidos por TextParse para uma tabela de JuliaDB
#    textp -  TextParse
#    colindex - Numeric (posição da coluna que será indexada)
#    colseries - Numeric (posição da outra coluna a incluir)
# Assume apenas 2 colunas, sendo a coluna de datas (colindex) a que se irá indexar colindex. 

function juliadb(textp, colindexes, nomes)
   return  table(textp[1]..., names = nomes, pkey = colindexes)
end

# colindexes e.g. (:col1, :col2, :col3, :col4)
function juliadb(textp, colindexes)
    return  table(textp[1]..., names = map(Symbol,textp[2]), pkey = colindexes)
 end
 
 function juliadb(textp)
    return  table(textp[1]..., names = map(Symbol,textp[2]))
 end


# CSV: Remote URL -> in-memory JuliaDB, IndexedTables
# using JuliaDB
function bceJDB(myURL::String, nomes::Array{Symbol,1})
    newtable = TextParse.csvread(IOBuffer(HTTP.get(myURL).body), skiplines_begin=5, header_exists=false)
    tabela =  table(newtable[1][1], newtable[1][2], names = nomes, pkey = (nomes[1]))
    return tabela
end

# CSV: Remote URL -> in-memory JuliaDB(|>table), DataFrames(|>DataFrame), StatsModels, StatsPlots, IndexedTables,...
# using CSVFiles, FileIO
function bceCSVFiles(myURL::String, nomes::Array{Symbol,1})
    tabela = FileIO.load(Stream(format"CSV", IOBuffer(HTTP.get(myURL).body)), skiplines_begin=5,header_exists=false, colnames = nomes) |> table
    return tabela
end

# CSV: Remote URL -> in-memory SQLite, ODBC, DataFrames
# using CSV
# CSV.read(fullpath::Union{AbstractString,IO}, sink::Type{T}=DataFrame, args...; kwargs...) => typeof(sink)
function bceCSV(myURL::String, nomes::Array{Symbol,1})
    tabela = CSV.read(IOBuffer(HTTP.get(myURL).body), datarow = 6, header = nomes, missingstring=" ")
    return tabela
end

function obter(series; inicio="", fim="")       
    
    tabela = JuliaDB.table([1])

    if series == :NSS
        nssURL = "http://sdw.ecb.europa.eu/quickviewexport.do?trans=N&updated=&start=$(inicio)&end=$(fim)&SERIES_KEY=165.YC.B.U2.EUR.4F.G_N_A.SV_C_YM."
        print("Modelo Svensson >")
        for simbolo in SVENSSON
            fonte = conformar(nssURL*"$(simbolo)&format=csvdata")
            resp = download(fonte, saltar = 5, header = false)
            tabelaN = juliadb(resp, (:Data), [:Data, simbolo])
            if simbolo == :BETA0
                tabela = tabelaN
            else
                tabela = join(tabela, tabelaN)
            end
            print("\t",simbolo)
        end
        println("\n",tabela,"\n")
        return tabela
    
    elseif series == :MM
        mmiURL = "http://sdw.ecb.europa.eu/quickviewexport.do?trans=N&start=$(inicio)&end=$(fim)&SERIES_KEY="
        println("\n")
        for i = 1:4
            print(MMIsimbolo[i], "\t")
            fonte = conformar(mmiURL*"$(MMIcodigo[i])&type=csv")
            resp = download(fonte, saltar = 5, header = false)
            tabelaN = juliadb(resp, (:Data), [:Data, MMIsimbolo[i]])
            if i == 1
                tabela = tabelaN
            else
                tabela = join(tabela, tabelaN)
            end
        end
        for simbolo in EURIBOR
            print(simbolo,"\t")
            euriborURL = "http://webstat.banque-france.fr/en/quickviewexport.do?SERIES_KEY=213.FM.D.U2.EUR.FR2.MM.$(simbolo)D_.HSTA&type=csv"
            fonte = conformar(euriborURL)
            resp = download(fonte, saltar=6, datatipo = "d-m-y", header = false, na=["-"])
            tabelaN = juliadb(resp, (:Data), [:Data, simbolo])
            tabela = join(tabela, tabelaN)
        end
        println("\n",tabela,"\n")
        return tabela
    
    elseif series == :RFR
        rfrURL = "http://www.repofundsrate.com/csv/"
        print("Taxas Fundos Repo EUR >")
        for i = 1:6
            fonte =  conformar(rfrURL*RFRurl[i])
            resp = download(fonte, saltar =0, header=true)
            tabelaN = juliadb(resp, (:Data), [:Data, :Description, RFRsimbolo[i], :IndexVol, :InicialVol])
            tabelaN = select(tabelaN, All(:Data, RFRsimbolo[i]))
            if i == 1
                tabela = tabelaN
            else
                tabela = join(tabela, tabelaN)
            end
            print("\t",RFRsimbolo[i])
        end
        println("\n",tabela, "\n")
        return tabela

    else series in FXALL
        if series == :FX
            fxURL = "http://sdw.ecb.europa.eu/quickviewexport.do?start=$(inicio)&end=$(fim)&SERIES_KEY=120.EXR.D."
            for simbolo in FXsimbolo
                print(simbolo,"\t")
                fonte = conformar(fxURL*"$(simbolo).EUR.SP00.A&type=csv")
                resp = download(fonte, saltar = 5, header = false,  na = ["-"])
                tabelaN = juliadb(resp, (:Data), [:Data, simbolo])
                if simbolo == :USD
                    tabela = tabelaN
                else
                    tabela = join(tabela, tabelaN)
                end
            end
        else
            fxURL = "http://sdw.ecb.europa.eu/quickviewexport.do?start=$(inicio)&end=$(fim)&SERIES_KEY=120.EXR.D.$(series).EUR.SP00.A&type=csv"
            fonte = conformar(fxURL)
            resp = download(fonte, saltar = 5, header = false,  na = ["-"])
            tabela = juliadb(resp, (:Data), [:Data, series])
        end    
        println("\n\n",tabela,"\n")
        return tabela
    end    
end

# top é o header
function obter(url::String; na =[""], saltar = 0, top = true, data = "y-m-d")
    fonte = conformar(url)
    resp = download(fonte, saltar = saltar, datatipo= data, header = top, na = na)
    tabela = juliadb(resp)
    println("\n",tabela)
    return tabela       
end