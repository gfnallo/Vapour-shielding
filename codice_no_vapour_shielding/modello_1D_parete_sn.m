%%% Modello 1D parete con proprietà dipendenti dalla temperatura +
%%% evaporazione del LM + ebollizione nucleata (no vapour shielding)

clear all
close all
clc

set(0,'DefaultAxesLineWidth',0.7)
set(0,'defaultlinelinewidth',2)
set(0,'DefaultAxesFontSize',10)

%ipotesi 1): proprietà non dipendenti dalla pressione;  
%ipotesi 2): flusso imposto minore del flusso critico, quindi sempre %ebollizione nucleata
%ipotesi 3): deflusso dell'acqua completamente sviluppato e a regime (invece la temperatura della parete evolve nel tempo)
%ipotesi 4): proprietà calcolate a Twater (e non alla temperatura media di
%uscita ed entrata)
%ipotesi 5): fattore f=0.5 dal Roccella per la media pesata delle proprietà
%della CPS
%ipotesi 6): no resistenza di contatto e no resistenza tra CuCrZr e tubo (solo convettiva)
%ipotesi 7): no interferenza tra i tubi e no shape factor del 2D

%modello 1D composto da CPS e CuCrZr. Parametri geometrici e
%termofluidodinamici dal paper di Roccella. La quotatura del pezzo, non
%ricavabile interamente dal paper, è stata completata attraverso la proporzione delle misure della figura sul paper 

%% Proprietà termofisiche
Tw=140; %[°C]
Tin=Tw;  
LCuCrZr=8.46e-3; %[m]
LCPS=2e-3; %[m] 
Ltot=LCPS+LCuCrZr;
DD=8e-3; %[m]
vel=12; %[m/s]
delta=0.8e-3; %[m]   %twisted tape thickness (fonte: SOLPS-ITER simplified heat transfer model for plasma facing components, Stefano Carli)
diameter=4*(pi*(DD^2)/4-delta*DD)/(pi*DD+2*DD-2*delta);  %diametro idraulico (fonte: SOLPS-ITER simplified heat transfer model for plasma facing components, Stefano Carli)
speed=vel*(1+pi^2/4/4)^0.5; %velocità con twisted tape (fonte: SOLPS-ITER simplified heat transfer model for plasma facing components, Stefano Carli)
RR=8.314;  %costante dei gas

%acqua (saturated water @ Tw da Incropera); b:410K, t=420K:
cp_b=4.278e3; %[J/kg/K]
cp_t=4.302e3; %[J/kg/K]
rho_b=1/1.077*1e3; %[kg/m^3]
rho_t=1/1.088*1e3; %[kg/m^3]
mu_b=200e-6; %[N*s/m^2]
mu_t=185e-6; %[N*s/m^2]
kk_b=688e-3; %[W/m/K]
kk_t=688e-3; %[W/m/K]
Pr_b=1.24;
Pr_t=1.16; 

mu_f_water=@(T) 2.4638e-5*exp(4.42e-4*50+(4.703e3-50*0.9565)/RR/(T+273.15-140.3-50*1.24e-2));  %[Pa*s] %(fonte:Dependence of Water Viscosity on Temperature and Pressure, E. R. Likhachev)

cp_w=cp_b+(Tw+273.15-410)/(420-410)*(cp_t-cp_b); %[J/kg/K]
rho_w=rho_b+(Tw+273.15-410)/(420-410)*(rho_t-rho_b); %[kg/m^3]
mu_w=mu_b+(Tw+273.15-410)/(420-410)*(mu_t-mu_b); %[N*s/m^2]
kk_w=kk_b+(Tw+273.15-410)/(420-410)*(kk_t-kk_b); %[W/m/K]
Pr_w=Pr_b+(Tw+273.15-410)/(420-410)*(Pr_t-Pr_b);

%CuCrZr-da file forniti
rho_cucrzr=@(T) 8900.*(1 - 0.000003.*(7.20e-9.*T.^3 - 9.05e-6.*T.^2+6.24e-3.*T+1.66*1e1).*(T - 20)); %T in °C %[kg/m^3]
cp_cucrzr=@(T) 6.32e-6.*T.^2 + 9.49e-2.*T + 3.88e2;  %T in °C  %[J/kg/K]
kk_cucrzr=@(T) 2.11e-7.*T.^3-2.83e-4.*T.^2 + 1.38e-1.*T + 3.23e2;  %T in °C %[W/m/K]

%Sn-da file forniti
rho_sn=@(T) 6979-0.652.*(T+273.15-505.08); %T in °C  %[kg/m^3]
mu_sn=@(T) 1e-3*10.^(-0.408+343.4./(T+273.15));  %T in °C %[N*s/m^2]
kk_sn=@(T) 13.90+0.02868.*(T+273.15);  %T in °C %[W/m/K]
cp_sn=@(T) (9.97-9.15e-3.*(T+273.15)+6.5e-6.*(T+273.15).^2)/(118.71*1e-3)*4.184;  %T in °C  %[J/kg/K]

%W-da file forniti
rho_tung=@(T) 1e3.*(19.3027-2.3786e-4.*T-2.2448e-8.*T.^2); %T in °C  %[kg/m^3]
cp_tung=@(T) 128.308+3.2797e-2.*T-3.4097e-6.*T.^2; %T in °C  %[J/kg/K]
kk_tung=@(T) 174.9274-0.1067.*T+5.0067e-5.*T.^2-7.8349e-9.*T.^3; %T in °C %[W/m/K]

%CPS-proprietà ricavate attraverso una media pesata come dal paper fornito
%(Power handling of a liquid-metal based CPS structure under high steady-state heat and particle fluxes, Morgan et al.)
ff=0.5; 
kk_CPS_sn=@(T) ff*kk_sn(T)+(1-ff)*kk_tung(T); %[W/m/K]
rho_CPS_sn=@(T) ff*rho_sn(T)+(1-ff)*rho_tung(T);  %[kg/m^3]
cp_CPS_sn=@(T) ff*cp_sn(T)+(1-ff)*cp_tung(T); %[J/kg/K]

%% Calcolo dei parametri per il coefficiente di scambio termico (HTC)
Re_w=rho_w*speed*diameter/mu_w;
pressure=5; %[MPa]
T_sat=263.8; %[°C] temperatura di saturazione a 5 MPa
factor=1.15; %fattore di correzione per twisted tape (fonte: SOLPS-ITER simplified heat transfer model for plasma facing components, Stefano Carli) 
hh_st=@(Twall) factor*kk_w/diameter*0.027*(Re_w^(4/5))*(Pr_w^(1/3))*(mu_w/mu_f_water(Twall))^0.14; %correlazione di Sieder-Tate modificata %[W/m^2/K]

%% evaporazione LM
eta=1.66;
fredep=0.9;
molecular_weight=118.71*1.66054*1e-27; %[kg] 
Boltzmann=1.38*1e-23; %[J/K]
Avogadro=6.022*1e23; %[mol^-1]
enthalpy=@(T) -1285.372+28.4512*(T+273.15); %[J/mol]  %da proprietà Sn
vapor_pressure=@(T) 101325*10^(5.262-15332/(T+273.15));  %[Pa]  %da proprietà Sn
molar_flux=@(T) eta*fredep*vapor_pressure(T)/sqrt(2*pi*molecular_weight*Boltzmann*(273.15+T))/Avogadro;  %[mol/m^2/s]

%% flusso iniziale
q_par_u=1.6e9; %[W/m^2]  %da design DTT
beta=pi/6; %[°] %inclinazione delle linee di campo rispetto al target, da design DTT
B_theta_B_u=1.7/6.2; %(B_theta/B)_u  %da design DTT
B_theta_B_u___B_theta_B_t=3;  %(B_theta/B)_u/%(B_theta/B)_t  %da design DTT
rapp_aree=sin(beta)*B_theta_B_u/B_theta_B_u___B_theta_B_t;
coeff_mitigazione=1.8; %coefficiente di mitigazione dovuto al gas nobile

%% Soluzione
%Discretizzazione nello spazio
dx=1e-5;
xx1=(0:dx:LCuCrZr)'; %pedice1=CuCrZr
ni=length(xx1); %nodo di interfaccia
xx2=(LCuCrZr+dx:dx:Ltot)'; %pedice2=CPS
xx=[xx1;xx2];
nn=length(xx);

%Discretizzazione nel tempo
dt=0.1;

qq=[5e6,10e6,20e6,q_par_u*rapp_aree/coeff_mitigazione];  %analisi termica per diversi flussi imposti

for jj=1:length(qq)
    
    %Condizione iniziale
    Tm=Tin*ones(nn,1);
    time(1)=0;

    %Preallocazione matrice
    AA=zeros(nn,nn);

    figure(jj)
    line(1)=plot(xx*1e3,Tm,'displayname','t_0');
    hold on
    grid minor
    xlim([0,xx(end)*1e3])
    xlabel("Spessore [mm]")
    ylabel("Temperatura [°C]")
    title(["Andamento temperatura nel target con un flusso di" num2str(qq(jj)/1e6) "MW/m^2"])

    %Metodo Eulero Implicito con Frozen Coefficients
    ii=1;
    precisione(1)=1;
    while precisione(ii)>1e-2    %per arrivare a stazionario
        %Matrice
        alpha=(kk_cucrzr(Tm)./(rho_cucrzr(Tm).*cp_cucrzr(Tm))).*(xx<=LCuCrZr)+(kk_CPS_sn(Tm)./(rho_CPS_sn(Tm).*cp_CPS_sn(Tm))).*(xx>LCuCrZr); 

        aa=alpha*dt./dx^2;
        inferiore=[-aa(2:end);0];
        main=(1+2*aa);
        superiore=[0;-aa(1:end-1)];
        DD=[inferiore,main,superiore];
        AA=spdiags(DD,-1:1,nn,nn);
        
        %Calcolo del HTC-metodo iterativo Newton
        toll=1e-5;
        funct=@(xx) hh_st(Tm(1))*(xx-Tw)-15500*((pressure^(1.156))*(1.8*abs(xx-T_sat))^(2.046/(pressure^0.0234))); %correlazione di Bergles-Rohsenow
        dfunct=@(xx) hh_st(Tm(1))-15500*(pressure^(1.156))*(2.046/(pressure^0.0234))*((1.8*abs(xx-T_sat))^(2.046/(pressure^0.0234)))*1.8;

        [T_ONB]=myNewton(funct,dfunct,T_sat+1,toll); %+1 perché la funzione non è definita in T_sat 
        
        if Tm(1)>T_ONB   %si ha ebollizione nucleata
            qq_st=hh_st(Tm(1))*(Tm(1)-Tw);
            qq_nb=1e6*(exp(pressure/8.7)*(Tm(1)-T_sat)/22.65)^2.8;  %correlazione di Thoms-CEA 
            qq_0=1e6*(exp(pressure/8.7)*(T_ONB-T_sat)/22.65)^2.8;
            
            qq_tot=sqrt(qq_st^2+(qq_nb^2)*((1-qq_0/qq_nb)^2));
            hh=qq_tot/(Tm(1)-Tw);
        else
            hh=hh_st(Tm(1));    %convezione con acqua monofase sottoraffreddata
        end
           
        %Condizioni al contorno
        
            %Robin primo nodo
            AA(1,1)=-(1+dx*hh/kk_cucrzr(Tm(1)));
            AA(1,2)=1;

            %Interfaccia
            AA(ni,ni-1)=kk_cucrzr(Tm(ni-1))/kk_CPS_sn(Tm(ni-1));  
            AA(ni,ni)=-1-kk_cucrzr(Tm(ni))/kk_CPS_sn(Tm(ni));
            AA(ni,ni+1)=1;

            %Neumann non omogenea
            AA(end,end-1)=-1;
            AA(end,end)=1;

        %Vettore termini noti
        bb=Tm;
        bb(1)=-Tw*hh*dx/kk_cucrzr(Tm(1));
        bb(ni)=0;
        bb(end)=(qq(jj)-molar_flux(Tm(end))*enthalpy(Tm(end)))*dx/kk_CPS_sn(Tm(end));
        
        if jj==4
           flux_evap(ii)=molar_flux(Tm(end))*enthalpy(Tm(end));
        end

        %Soluzione
        TT=AA\bb;
        ii=ii+1;
        time(ii)=time(ii-1)+dt;
        precisione(ii)=norm(TT-Tm)/norm(TT-Tw);
        Tm=TT;

        line(ii+1)=plot(xx*1e3,TT,'displayname',['t=' num2str(time(ii)) 's']);
        pause(0.2)
    end

    legend(line(1:2:ii+1),'location','nw')  %legenda solo di alcuni plot

end

%% andamento del HTC
temp=(130:310);
for ii=1:length(temp)
    funct=@(xx) hh_st(temp(ii))*(xx-Tw)-15500*((pressure^(1.156))*(1.8*abs(xx-T_sat))^(2.046/(pressure^0.0234)));
    dfunct=@(xx) hh_st(temp(ii))-15500*(pressure^(1.156))*(2.046/(pressure^0.0234))*((1.8*abs(xx-T_sat))^(2.046/(pressure^0.0234)))*1.8;

    [T_ONB]=myNewton(funct,dfunct,T_sat+1,toll); 
    
    if temp(ii)>T_ONB
        qq_st=hh_st(temp(ii))*(temp(ii)-Tw);
        qq_nb=1e6*(exp(pressure/8.7)*(temp(ii)-T_sat)/22.65)^2.8;    %Thoms-CEA correlation
        qq_0=1e6*(exp(pressure/8.7)*(T_ONB-T_sat)/22.65)^2.8;

        qq_tot=sqrt(qq_st^2+(qq_nb^2)*((1-qq_0/qq_nb)^2));

        hh=qq_tot/(temp(ii)-Tw);
    else
        hh=hh_st(temp(ii));
    end
    HTC(ii)=hh;
end
    
figure(jj+1)
plot(temp,HTC*1e-3)
grid minor
xlim([temp(1),temp(end)])
xlabel("Temperatura [°C]")
ylabel("HTC [kW/m^2/K]")
title('HTC in funzione della temperatura interna del tubo')

figure(jj+2)
plot(time(1:length(flux_evap)),flux_evap/1e6,'r')
xlabel('Tempo [s]')
ylabel('Potenza termica [MW/m^2]')
grid minor
title('Flusso evaporato  nel tempo')

%% Concentrazione del vapore 
uu=(700:1100);
vapore=zeros(size(uu));

for kk=1:length(uu)
    vapore(kk)=molar_flux(uu(kk))*Avogadro;
end

figure(jj+3)
semilogy(uu,vapore)
grid minor
xlabel('Temperatura [°C]')
ylabel('Flusso di particelle [#/m^2/s]')
title('Evaporazione stagno')

%% Calcolo del flusso critico - correlazione di Tong75 modificata per twisted tape (da design ITER, fonte: SOLPS-ITER simplified heat transfer model for plasma facing components, Stefano Carli)
f_0=8/(Re_w^0.6)*(diameter/(12.7*1e-3))^0.32;
i_fg=1639.39e3; %calore latente di vaporizzazione a 5MPa [J/kg]
rho_v=26.67; %densità vapore a Tsat [kg/m^3]
J_a=cp_w*(T_sat-Tw)/i_fg*rho_w/rho_v;
Cf=1.67; %fattore di correzione

critical_flux=Cf*0.23*f_0*rho_w*speed*i_fg*(1+0.00216*((pressure/22.09)^1.8)*J_a*Re_w^0.5);

fprintf('Il flusso critico è %.2f [MW/m^2]\n',critical_flux*1e-6)