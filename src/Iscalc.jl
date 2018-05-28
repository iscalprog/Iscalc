module Iscalc

# Make sure you do
# using DataFrames
# using SQLite
# in that order in a fresh Julia session to ensure the conversion methods get defined

using Base.Dates, Requests, JuliaDB, CSV, FileIO, DataFrames, TextParse, HTTP, SQLite, DataStreams, Missings
using BusinessDays, OnlineStats, Plots, LaTeXStrings 
#using IJulia
#using Compat

include("GetData.jl")   
include("OT.jl")      
include("API.jl")

export JCorridos

println("\n\nISCALC - versão 0.3.2 <2017-04-25>")


end # module
