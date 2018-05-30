#using BenchmarkTools, Roots, Distributions
# Input from user

function input(prompt::String = "")::String
    print(prompt)
    return chomp(readline())
end


function fdesc(r,t,compos = 'c')
    if compos == 'c'
        czero = 1.*exp.(-r.*t)
    else
        czero = 1./((r.+1).^t)
    end
    return czero
end

function actualz(fd,t,compos='c')
    if compos == 'c'
        re = - log.(fd)./t
    else
        re = fd.^(-1./t).- 1 
    end
    return re
end

function bootstrap(p, c, m,compos='c')
    n = length(c)
    cfMat = zeros(n,n)
    for i = 1:n, j = 1:i #fill the cfMat matrix
        cfMat[i,j] = cfMat[i,j] + c[i]
        if i == j #along diagonal, add face value (1)
            cfMat[i,j] = cfMat[i,j] + 1
        end
    end
    B = cfMat\p
    return B, actualz.(B,m, compos) 
end


function nss(m,b0,b1,b2,b3, tau, tau2)
    f =  b0 + b1*exp.(-m/tau) + b2*(m/tau).*exp.(-m/tau) + b3*(m/tau2).*exp.(-m/tau2)   
    s =  b0 + b1*(1 - exp.(-m/tau))./(m/tau) + b2*((1 - exp.(-m/tau)) ./(m/tau) - exp.(-m/tau)) + b3*((1 - exp.(-m/tau2))./(m/tau2) - exp.(-m/tau2))  
    d = exp.(-s.*m)         
    return s,f,d
end  

function CouponPago(DataReferencia,Mes,Dia)
    if DataReferencia >= Date(Year(DataReferencia),Mes,Dia)
        return true
    else
        return false
    end
end

function DiasCorridos(DataReferencia,Mes,Dia)
    DataCouponPago = Date(Year(DataReferencia),Mes,Dia)
    if DataReferencia >= DataCouponPago
        DiasJurosCorridos = DataReferencia - DataCouponPago
    else
        DataCouponPago = Date(Year(DataReferencia)-Year(1),Mes,Dia)
        DiasJurosCorridos = DataReferencia - DataCouponPago
    end
    return Dates.value(DiasJurosCorridos), DataCouponPago
end

function JCorridos(dados,DataReferencia)
    NEmissões = size(dados)[1] 
    a = []
    for i = 1:NEmissões
        Mes = Month(Date(dados[i,2]))
        Dia = Day(Date(dados[i,2])) 
        DiasJurosCorridos = DiasCorridos(DataReferencia,Mes,Dia)[1]
        JurosCorridos = DiasJurosCorridos / 365 * dados[i,3] * 100
        push!(a,dados[i,1])
        push!(a,DiasCorridos(DataReferencia,Mes,Dia)[2])
        push!(a,DiasJurosCorridos)
        push!(a,dados[i,3])
        push!(a,JurosCorridos)
        push!(a,dados[i,4])
        push!(a,JurosCorridos + dados[i,4])
    end
    a = reshape(a,7,:)
    return JuliaDB.table(a[1,:], a[2,:], a[3,:], a[4,:], a[5,:], a[6,:],a[7,:], names=[:ISIN, :UCouponPago,:DCorridos, :TxCoupon, :JCorridos, :PLimpo, :PLiquid], pkey=(:ISIN))
end

function FluxosCaixa(dados,DataReferencia)
    NEmissões = size(dados)[1]
    b=[]
    for i = 1:NEmissões
        Mes = Month(Date(dados[i,2]))
        Dia = Day(Date(dados[i,2])) 
        if CouponPago(DataReferencia,Mes,Dia) == true
            inicio = Dates.value(Year(DataReferencia)) + 1
        else
            inicio = Dates.value(Year(DataReferencia))
        end
        fim = Dates.value(Year(Date(dados[i,2])))
        for j = inicio:fim
            push!(b,dados[i,1])
            DataCF = tobday(:TARGET, Date(j, Mes, Dia))
            push!(b,DataCF)
            tenor = Dates.value(DataCF - DataReferencia)/365
            push!(b,tenor)
            if j == fim
                push!(b, (1 + dados[i,3])*100)
            else
                push!(b, dados[i,3]*100)
            end
        end
    end
    b = reshape(b,4,:)
    return JuliaDB.table(b[1,:], b[2,:], b[3,:], b[4,:],names=[:ISIN, :Data, :Tenores, :FluxosCaixa], pkey=(:Data, :ISIN))
end

function fdesconto(nss, tenores, janela_obs = 1:400) 
    nobs = length(nss) # Número datas disponíveis para os parâmetros NSS  
    NTenores = length(tenores)
    a = []
    nobs_plus = nobs + 1 # Se janela_obs começar em 1 então ordem obs = nobs 
    for i = janela_obs
        obs = nobs_plus - i
        push!(a, nss[obs][1])
        b0 = nss[obs][2]
        b1 = nss[obs][3]
        b2 = nss[obs][4]
        b3 = nss[obs][5]
        tau = nss[obs][6]
        tau2 = nss[obs][7]
        for m in tenores
            spot =  b0 + b1*(1 - exp(-m/tau))/(m/tau) + b2*((1 - exp(-m/tau)) /(m/tau) - exp(-m/tau)) + b3*((1 - exp(-m/tau2))/(m/tau2) - exp(-m/tau2))
            desc = exp(-spot/100*m)
            push!(a, desc)
        end
    end
    fdes = reshape(a,NTenores,:)
    return permutedims(fdes, [2,1]) # Transposta: fdesc' não funciona pois temos datas
end

function fspot(nss, tenores, janela_obs = 1:400) 
    nobs = length(nss) # Número datas disponíveis para os parâmetros NSS  
    NTenores = length(tenores)
    a = []
    nobs_plus = nobs + 1 # Se janela_obs começar em 1 então ordem obs = nobs 
    for i = janela_obs
        obs = nobs_plus - i
        push!(a, nss[obs][1]) 
        b0 = nss[obs][2]
        b1 = nss[obs][3]
        b2 = nss[obs][4]
        b3 = nss[obs][5]
        tau = nss[obs][6]
        tau2 = nss[obs][7]
        for m in tenores
            spot =  b0 + b1*(1 - exp(-m/tau))/(m/tau) + b2*((1 - exp(-m/tau)) /(m/tau) - exp(-m/tau)) + b3*((1 - exp(-m/tau2))/(m/tau2) - exp(-m/tau2))
            push!(a, spot)
        end
    end
    funspot = reshape(a, NTenores + 1,:)
    return permutedims(funspot, [2,1]) 
end

function fcaixa(tcoupon,freq, mat, capital, amort=false)
    numcf = convert(Int64,ceil(freq * mat))   #
    t1 = mod(mat, 1/freq)
    tVec = fill(t1,numcf)
    for i = 2:numcf
        tVec[i] = tVec[i-1] + 1/freq
    end
    if amort == false
        coupon = (tcoupon/freq) * capital
        cfVec = fill(coupon, numcf)
        cfVec[numcf] = coupon + capital
    else
        cfVec = zeros(numcf)
        for i = 1:numcf
            coupon = (tcoupon/freq) * (capital - (i-1)*capital/numcf)
            cfVec[i] = coupon + capital / numcf
        end
    end
    return cfVec, tVec
end

function valobrig(cf,r,t,compos='c')
    if compos == 'c'
        cdisc = cf.*exp.(-r.*t)
        P = sum(cdisc)
    else
        cdisc = cf./((r.+1).^t)
        P = sum(cdisc)
    end
    return P
 end

function ytm(p,cf,t)
    ytm = fzero(y->valobrig(cf,y,t)-p,0.0)
    return ytm
end

function duration(preço,cflow,m,ytm,compos='c')
    if compos == 'c'
       cdisc = m.*cflow .*exp.(- ytm .* m) 
       dMod = dMac = sum(cdisc)/preço 
    else
        cdisc = cflow.*m./((1+ytm).^(m.+1)) 
        D = sum(cdisc) # Duration, row vector
        dMod = D/preço # Modified duration
        dMac = D*(1+ytm)/preço # Macaulays duration
    end
    return dMod, dMac
end


function VaR(alfa,sigma, portfolio)
    var = -quantile(Normal(0,1),alfa) * sigma * portfolio
    return var
end

function ETL(alfa, sigma, portfolio)
    z = quantile(Normal(0,1),alfa)
    etl = pdfNormal(z)/alfa * sigma * portfolio
    return etl
end

function nss(m,svensson)
    datas = select(svensson,:Data)
    nlinhas = length(datas) 
    b0 = select(svensson,:BETA0)
    b1 = select(svensson,:BETA1)
    b2 = select(svensson,:BETA2)
    b3 = select(svensson,:BETA3)
    tau = select(svensson,:TAU1)
    tau2 = select(svensson,:TAU2)
    s = Array{Float64}(nlinhas)
    f = Array{Float64}(nlinhas)
    d = Array{Float64}(nlinhas)
    for i = 1:nlinhas
        # Taxas spot
        s[i] =  b0[i] + b1[i]*(1 - exp(-m/tau[i]))/(m/tau[i]) + b2[i]*((1 - exp(-m/tau[i])) /(m/tau[i]) - exp(-m/tau[i])) + b3[i]*((1 - exp(-m/tau2[i]))/(m/tau2[i]) - exp(-m/tau2[i]))  
        # Taxas forward
        f[i] =  b0[i] + b1[i]*exp(-m/tau[i]) + b2[i]*(m/tau[i])*exp(-m/tau[i]) + b3[i]*(m/tau2[i])*exp(-m/tau2[i])   
        # Função de Desconto
        d[i] = exp(-s[i]*m/100)
    end   
    tabela = JuliaDB.table(datas,s,f,d,names=[:Data, :Spot, :Forward, :Desconto])
    return tabela   
end  


function bucketing(vk, v1,sigma1, v2, sigma2, corr12)
    cov12 = sigma1*sigma2*corr12
    sigmak = sigma1 + (vk-v1)/(v2-v1)*(sigma2-sigma1)
    a = sigma1^2+sigma2^2-2*cov12
    b = 2*(-sigma2^2+cov12)
    c = sigma2^2-sigmak^2
    raiz2 = (-b - sqrt(b^2-4*a*c))/(2*a)
    raiz1 = (-b + sqrt(b^2-4*a*c))/(2*a)
    minraiz = min(raiz1,raiz2)
    println(a,"\n",b,"\n",c)
    if  minraiz < 0
        return max(raiz1,raiz2)
    else
        return minraiz
    end
end