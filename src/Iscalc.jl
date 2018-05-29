VERSION >= v"0.6.0" && __precompile__(true)

module Iscalc

# Make sure you do
# using DataFrames
# using SQLite
# in that order in a fresh Julia session to ensure the conversion methods get defined

using Base.Dates, Requests, JuliaDB, CSV, FileIO, DataFrames, TextParse, HTTP, DataStreams, Missings, Roots, LaTeXStrings
using BusinessDays, OnlineStats

#using IJulia, SQLite
#using Compat

include("GetData.jl")   
include("OT.jl")      
include("API.jl")

export obter, JCorridos, FluxosCaixa, fspot, fdesconto
export euronextBonds, factsheet, catalogo
export load, save, table, column, join, merge, stack, unstack, select, reduce   #JUliaDB
export Mean, Quantile, Variance, Hist, value # OnlineStats 
export latexstring # Latexstrings
println("\n\nISCALC - versão 0.3.3 <2018-04-25>")


end # module
