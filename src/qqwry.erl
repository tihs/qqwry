%%%-------------------------------------------------------------------
%%% @author 徐仙华 <will@josenhuas-Mac-mini.local>
%%% @copyright (C) 2015, 徐仙华
%%% @doc
%%%
%%% @end
%%% Created :  7 Apr 2015 by 徐仙华 <will@josenhuas-Mac-mini.local>
%%%-------------------------------------------------------------------
-module(qqwry).
-author('xuxianhua1985@126.com').

-behaviour(gen_server).

%% API
-export([start_link/0, start_link/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-export([start/0, start/1, lookup/1, go/0, getProvinceName/1, look/1]).

-define(SERVER, ?MODULE).

-include("qqwry.hrl").

start() ->
    start(app, qqwry).

start(File) ->
    application:load(qqwry),
    application:set_env(qqwry, dbfile, File),
    start().

start(app, App) ->
    start_ok(App, application:start(App, transient)).

start_ok(_, ok) -> ok;
start_ok(_, {error, {already_started, _}}) -> ok;
start_ok(App, {error, {not_started, Dep}}) -> 
    case start(app, Dep) of
        ok ->
            start(app, App);
        _ ->
            erlang:error({app_start_fail, App})
    end;
start_ok(App, {error, Reason}) ->
    erlang:error({app_start_failed, App, Reason}).

    
    

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link()->
    start_link(?SERVER, 'qqwry.dat').

start_link(Name, File) ->
    gen_server:start_link({local, Name}, ?MODULE, File, []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init(DbFile) ->
    case default_db(DbFile) of
        error ->
            {error, {qqwry_db_not_found, DbFile}};
        DbFilePath ->
            case file:read_file(DbFilePath) of
                {ok, Data} ->
                    <<FirstIndex:32/integer-unsigned-little, LastIndex:32/integer-unsigned-little, _/binary>> = Data,
                    Count = (LastIndex - FirstIndex) div 7 + 1,
                    {ok, #qqwry_state{
                            data = Data,
                            length = byte_size(Data),
                            count = Count,
                            position = 0,
                            first_index = FirstIndex,
                            last_index = LastIndex,
                            filename = DbFile
                           }};
                _ ->
                    {error, {qqwry_db_read_error,DbFile}} 
            end
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({lookup, Ip}, _From, #qqwry_state{data=Data, first_index=FirstIndex, count=Count} = State) ->
    IpIndex = find(0, Count, Ip, FirstIndex, Data),
    IpOffset = FirstIndex + IpIndex * 7,
    AddressOffset = getInt3(Data, IpOffset + 4) + 4,
    <<_:AddressOffset/binary, AddressMode:1/binary, _/binary>> = Data,
    Reply = getAddress(AddressMode, Data, AddressOffset),
    {reply, Reply, State};
handle_call(filename, _From, State) ->
    {reply, State#qqwry_state.filename, State};
handle_call(_, _From, State) ->
    getAddress(0, <<0>>,0),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(stop, State) ->
    {stop, normal, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

default_db(File) ->
    AppDir = case code:which(?MODULE) of
                 cover_compiled -> "..";
                 F -> filename:dirname(filename:dirname(F))
             end,
    DbFile = filename:join([AppDir, "priv", erlang:atom_to_list(File)]),
    case filelib:is_file(DbFile) of
        true ->
            DbFile;
        false ->
            error
    end.

lookup(Ip) when is_integer(Ip) ->
    ProccessPid = get_worker(Ip),
    case whereis(ProccessPid) of 
        undefined ->
            35;
        Pid ->
            case gen_server:call(Pid, {lookup, Ip}) of
                {ok, Address, _ISP} ->
					
                    case getProvince(unicode:characters_to_binary(Address)) of 
						35->
							getCountry(unicode:characters_to_binary(Address));
						_ ->
							156
					end;
                _ ->
                    35
            end
    end;
    %% case whereis(qqwry) of
    %%     undefined ->
    %%         case gen_server:call(get_worker(Ip), {lookup, Ip}) of
    %%             {ok, _Address, _ISP} ->
    %%                 getProvince(unicode:characters_to_binary(Address));
    %%             _ ->
    %%                 "未知"
    %%         end;
    %%     Pid ->
    %%         unregister(qqwry),
    %%         register(qqwry_0, Pid),
    %%         FileName = gen_server:call(Pid, filename),
    %%         [qqwry_0|Workers] = qqwry_sup:worker_names(),
    %%         Specs = qqwry_sup:worker(Workers, FileName),
    %%         lists:map(fun(Spec) ->
    %%                           {ok, _Pid} = supervisor:start_child(qqwry_sup, Spec)
    %%                   end, Specs),
    %%         lookup(Ip)
    %% end;
lookup(Ip) ->
    IntIp = ip2long(Ip),
    lookup(IntIp).

look(Ip) ->
    ProvinceCode = lookup(Ip),
    getProvinceName(ProvinceCode).
    

ip2long(Ip) ->
    [A,B,C,D] = lists:map(fun erlang:list_to_integer/1, string:tokens(Ip, ".")),
    <<E:32/integer-big>> = <<A:8/integer, B:8/integer, C:8/integer, D:8/integer>>,
    E.

%% long2ip(Ip) ->
%%     <<A:8/integer, B:8/integer, C:8/integer, D:8/integer>> = <<Ip:32/integer>>,
%%     string:join(lists:map(fun erlang:integer_to_list/1, [A,B,C,D]), ".").

find(Bi, Ei, Ipint, FirstIndex, Data) ->
    case Ei - Bi of
        V when V =< 1 ->
            Bi;
        _ ->
            Mi = (Bi + Ei) div 2,
            Offset = FirstIndex + Mi * 7,
            <<_:Offset/binary, Index:32/integer-unsigned-little, _/binary>> = Data,
            if 
                Ipint =< Index ->
                    find(Bi, Mi, Ipint, FirstIndex, Data);
                true ->
                    find(Mi, Ei, Ipint, FirstIndex, Data)
            end
    end.

getInt3(Data, Offset) ->
    <<_:Offset/binary, Address:24/unsigned-integer-little, _/binary>> = Data,
    Address.

getAddress(<<16#01>>, Data, Offset) ->
    %% 国家记录地址
    AddressOffset = getInt3(Data, Offset + 1),
    <<_:AddressOffset/binary, CountryMode:1/binary, _/binary>> = Data,
    {CountryName, ISPOffset} = case CountryMode of
                                   <<16#02>> ->
                                       {Country, _} = getString(Data, getInt3(Data, AddressOffset + 1)),
                                       Country1 = case Country of
                                                      no_found ->
                                                          "海外";
                                                      _ ->
                                                          Country
                                                  end,
                                       {Country1, AddressOffset + 4};
                                   _ ->
                                       case getString(Data, AddressOffset) of
                                           {no_found, NextOffset} ->
                                               {"海外", NextOffset};
                                           {Country, NextOffset} ->
                                               {Country, NextOffset}
                                       end
                               end,
    ISPName = getISP(Data, ISPOffset),
    {ok, CountryName, ISPName};
getAddress(<<16#02>>, Data, Offset) ->
    CountryName = case getString(Data, getInt3(Data, Offset + 1)) of
                      {no_found, _} ->
                          "海外";
                      {Country, _} ->
                          Country;
                      _ ->
                          "海外"
                  end,
    ISPName = getISP(Data, Offset + 4),
    {ok, CountryName, ISPName};
getAddress(_, Data, Offset) ->
    {CountryName, ISPOffset} = case getString(Data, Offset) of
                                   {no_found, ISPAddress} ->
                                       {"海外", ISPAddress};
                                   R ->
                                       R
                               end,
    ISPName = getISP(Data, ISPOffset),
    {ok, CountryName, ISPName}.


getISP(Data, Offset) ->
    <<_:Offset/binary, ISPMode:1/binary, _/binary>> = Data,
    case ISPMode of
        <<16#01>> ->
            ISPAddress = getInt3(Data, Offset + 1),
            case ISPAddress of
                0 ->
                    "未知";
                _ ->
                    case getString(Data, ISPAddress) of
                        {no_found, _} ->
                            "未知";
                        {Name, _} ->
                            Name;
                        _  ->
                            "未知"
                    end
            end;
        <<16#02>> ->
            ISPAddress = getInt3(Data, Offset + 1),
            case ISPAddress of
                0 ->
                    "未知";
                _ ->
                    case getString(Data, ISPAddress) of
                        {no_found, _} ->
                            "未知";
                        {Name, _} ->
                            Name;
                        _  ->
                            "未知"
                    end
            end;
        _  ->
            case getString(Data, Offset) of
                {no_found, _} ->
                    "未知";
                {Name, _} ->
                    Name;
                _  ->
                    "未知"
            end
    end.

getString(Data, Offset) ->
    getString(Data, Offset, 0).


getString(Data, Offset, L) ->
    RelateOffset = Offset + L,
    <<_:RelateOffset/binary, Char:8/integer, _/binary>> = Data,
    case Char of 
        0 ->
            if 
                L > 0 ->
                    <<_:Offset/binary, Address:L/binary, _/binary>> = Data,
                    {gbk:decode(binary_to_list(Address)), RelateOffset + 1};
                true ->
                    {no_found, RelateOffset + 1}
            end;
        _ ->
            getString(Data, Offset, L + 1)
    end.

get_worker(Ip) ->
    lists:nth(1 + erlang:phash2(Ip) band 7, qqwry_sup:worker_names()).



getCountry(<<"中国"/utf8, _/binary>>) -> 156;
getCountry(<<"美国"/utf8, _/binary>>) -> 840;
getCountry(<<"台湾"/utf8, _/binary>>) -> 158;
getCountry(<<"日本"/utf8, _/binary>>) -> 392;
getCountry(<<"印度"/utf8, _/binary>>) -> 356;
getCountry(<<"法国"/utf8, _/binary>>) -> 250;
getCountry(<<"德国"/utf8, _/binary>>) -> 276;
getCountry(<<"英国"/utf8, _/binary>>) -> 826;
getCountry(<<"加蓬"/utf8, _/binary>>) -> 266;
getCountry(<<"安道尔"/utf8, _/binary>>) -> 20;
getCountry(<<"阿联酋"/utf8, _/binary>>) -> 784;
getCountry(<<"阿富汗"/utf8, _/binary>>) -> 4;
getCountry(<<"安提瓜和巴布达"/utf8, _/binary>>) -> 28;
getCountry(<<"安圭拉"/utf8, _/binary>>) -> 660;
getCountry(<<"阿尔巴尼亚"/utf8, _/binary>>) -> 8;
getCountry(<<"亚美尼亚"/utf8, _/binary>>) -> 51;
getCountry(<<"安哥拉"/utf8, _/binary>>) -> 24;
getCountry(<<"南极洲"/utf8, _/binary>>) -> 10;
getCountry(<<"阿根廷"/utf8, _/binary>>) -> 32;
getCountry(<<"美属萨摩亚"/utf8, _/binary>>) -> 16;
getCountry(<<"奥地利"/utf8, _/binary>>) -> 40;
getCountry(<<"澳大利亚"/utf8, _/binary>>) -> 36;
getCountry(<<"阿鲁巴"/utf8, _/binary>>) -> 533;
getCountry(<<"奥兰"/utf8, _/binary>>) -> 248;
getCountry(<<"阿塞拜疆"/utf8, _/binary>>) -> 31;
getCountry(<<"波斯尼亚和黑塞哥维那"/utf8, _/binary>>) -> 70;
getCountry(<<"巴巴多斯"/utf8, _/binary>>) -> 52;
getCountry(<<"孟加拉国"/utf8, _/binary>>) -> 50;
getCountry(<<"比利时"/utf8, _/binary>>) -> 56;
getCountry(<<"布基纳法索"/utf8, _/binary>>) -> 854;
getCountry(<<"保加利亚"/utf8, _/binary>>) -> 100;
getCountry(<<"巴林"/utf8, _/binary>>) -> 48;
getCountry(<<"布隆迪"/utf8, _/binary>>) -> 108;
getCountry(<<"贝宁"/utf8, _/binary>>) -> 204;
getCountry(<<"圣巴泰勒米"/utf8, _/binary>>) -> 652;
getCountry(<<"百慕大"/utf8, _/binary>>) -> 60;
getCountry(<<"文莱"/utf8, _/binary>>) -> 96;
getCountry(<<"玻利维亚"/utf8, _/binary>>) -> 68;
getCountry(<<"加勒比荷兰"/utf8, _/binary>>) -> 535;
getCountry(<<"巴西"/utf8, _/binary>>) -> 76;
getCountry(<<"巴哈马"/utf8, _/binary>>) -> 44;
getCountry(<<"不丹"/utf8, _/binary>>) -> 64;
getCountry(<<"布韦岛"/utf8, _/binary>>) -> 74;
getCountry(<<"博茨瓦纳"/utf8, _/binary>>) -> 72;
getCountry(<<"白俄罗斯"/utf8, _/binary>>) -> 112;
getCountry(<<"伯利兹"/utf8, _/binary>>) -> 84;
getCountry(<<"加拿大"/utf8, _/binary>>) -> 124;
getCountry(<<"科科斯（基林）群岛"/utf8, _/binary>>) -> 166;
getCountry(<<"刚果（金）"/utf8, _/binary>>) -> 180;
getCountry(<<"中非"/utf8, _/binary>>) -> 140;
getCountry(<<"刚果（布）"/utf8, _/binary>>) -> 178;
getCountry(<<"瑞士"/utf8, _/binary>>) -> 756;
getCountry(<<"科特迪瓦"/utf8, _/binary>>) -> 384;
getCountry(<<"库克群岛"/utf8, _/binary>>) -> 184;
getCountry(<<"智利"/utf8, _/binary>>) -> 152;
getCountry(<<"喀麦隆"/utf8, _/binary>>) -> 120;
getCountry(<<"哥伦比亚"/utf8, _/binary>>) -> 170;
getCountry(<<"哥斯达黎加"/utf8, _/binary>>) -> 188;
getCountry(<<"古巴"/utf8, _/binary>>) -> 192;
getCountry(<<"佛得角"/utf8, _/binary>>) -> 132;
getCountry(<<"库拉索"/utf8, _/binary>>) -> 531;
getCountry(<<"圣诞岛"/utf8, _/binary>>) -> 162;
getCountry(<<"塞浦路斯"/utf8, _/binary>>) -> 196;
getCountry(<<"捷克"/utf8, _/binary>>) -> 203;
getCountry(<<"吉布提"/utf8, _/binary>>) -> 262;
getCountry(<<"丹麦"/utf8, _/binary>>) -> 208;
getCountry(<<"多米尼克"/utf8, _/binary>>) -> 212;
getCountry(<<"多米尼加"/utf8, _/binary>>) -> 214;
getCountry(<<"阿尔及利亚"/utf8, _/binary>>) -> 12;
getCountry(<<"厄瓜多尔"/utf8, _/binary>>) -> 218;
getCountry(<<"爱沙尼亚"/utf8, _/binary>>) -> 233;
getCountry(<<"埃及"/utf8, _/binary>>) -> 818;
getCountry(<<"阿拉伯撒哈拉民主共和国"/utf8, _/binary>>) -> 732;
getCountry(<<"厄立特里亚"/utf8, _/binary>>) -> 232;
getCountry(<<"西班牙"/utf8, _/binary>>) -> 724;
getCountry(<<"埃塞俄比亚"/utf8, _/binary>>) -> 231;
getCountry(<<"芬兰"/utf8, _/binary>>) -> 246;
getCountry(<<"斐济"/utf8, _/binary>>) -> 242;
getCountry(<<"福克兰群岛"/utf8, _/binary>>) -> 238;
getCountry(<<"密克罗尼西亚联邦"/utf8, _/binary>>) -> 583;
getCountry(<<"法罗群岛"/utf8, _/binary>>) -> 234;
getCountry(<<"格林纳达"/utf8, _/binary>>) -> 308;
getCountry(<<"格鲁吉亚"/utf8, _/binary>>) -> 268;
getCountry(<<"法属圭亚那"/utf8, _/binary>>) -> 254;
getCountry(<<"根西"/utf8, _/binary>>) -> 831;
getCountry(<<"加纳"/utf8, _/binary>>) -> 288;
getCountry(<<"直布罗陀"/utf8, _/binary>>) -> 292;
getCountry(<<"格陵兰"/utf8, _/binary>>) -> 304;
getCountry(<<"冈比亚"/utf8, _/binary>>) -> 270;
getCountry(<<"几内亚"/utf8, _/binary>>) -> 324;
getCountry(<<"瓜德罗普"/utf8, _/binary>>) -> 312;
getCountry(<<"赤道几内亚"/utf8, _/binary>>) -> 226;
getCountry(<<"希腊"/utf8, _/binary>>) -> 300;
getCountry(<<"南乔治亚和南桑威奇群岛"/utf8, _/binary>>) -> 239;
getCountry(<<"危地马拉"/utf8, _/binary>>) -> 320;
getCountry(<<"关岛"/utf8, _/binary>>) -> 316;
getCountry(<<"几内亚比绍"/utf8, _/binary>>) -> 624;
getCountry(<<"圭亚那"/utf8, _/binary>>) -> 328;
getCountry(<<"香港"/utf8, _/binary>>) -> 344;
getCountry(<<"赫德岛和麦克唐纳群岛"/utf8, _/binary>>) -> 334;
getCountry(<<"洪都拉斯"/utf8, _/binary>>) -> 340;
getCountry(<<"克罗地亚"/utf8, _/binary>>) -> 191;
getCountry(<<"海地"/utf8, _/binary>>) -> 332;
getCountry(<<"匈牙利"/utf8, _/binary>>) -> 348;
getCountry(<<"印尼"/utf8, _/binary>>) -> 360;
getCountry(<<"爱尔兰"/utf8, _/binary>>) -> 372;
getCountry(<<"以色列"/utf8, _/binary>>) -> 376;
getCountry(<<"马恩岛"/utf8, _/binary>>) -> 833;
getCountry(<<"英属印度洋领地"/utf8, _/binary>>) -> 86;
getCountry(<<"伊拉克"/utf8, _/binary>>) -> 368;
getCountry(<<"伊朗"/utf8, _/binary>>) -> 364;
getCountry(<<"冰岛"/utf8, _/binary>>) -> 352;
getCountry(<<"意大利"/utf8, _/binary>>) -> 380;
getCountry(<<"泽西"/utf8, _/binary>>) -> 832;
getCountry(<<"牙买加"/utf8, _/binary>>) -> 388;
getCountry(<<"约旦"/utf8, _/binary>>) -> 400;
getCountry(<<"肯尼亚"/utf8, _/binary>>) -> 404;
getCountry(<<"吉尔吉斯斯坦"/utf8, _/binary>>) -> 417;
getCountry(<<"柬埔寨"/utf8, _/binary>>) -> 116;
getCountry(<<"基里巴斯"/utf8, _/binary>>) -> 296;
getCountry(<<"科摩罗"/utf8, _/binary>>) -> 174;
getCountry(<<"圣基茨和尼维斯"/utf8, _/binary>>) -> 659;
getCountry(<<"朝鲜"/utf8, _/binary>>) -> 408;
getCountry(<<"韩国"/utf8, _/binary>>) -> 410;
getCountry(<<"科威特"/utf8, _/binary>>) -> 414;
getCountry(<<"开曼群岛"/utf8, _/binary>>) -> 136;
getCountry(<<"哈萨克斯坦"/utf8, _/binary>>) -> 398;
getCountry(<<"老挝"/utf8, _/binary>>) -> 418;
getCountry(<<"黎巴嫩"/utf8, _/binary>>) -> 422;
getCountry(<<"圣卢西亚"/utf8, _/binary>>) -> 662;
getCountry(<<"列支敦士登"/utf8, _/binary>>) -> 438;
getCountry(<<"斯里兰卡"/utf8, _/binary>>) -> 144;
getCountry(<<"利比里亚"/utf8, _/binary>>) -> 430;
getCountry(<<"莱索托"/utf8, _/binary>>) -> 426;
getCountry(<<"立陶宛"/utf8, _/binary>>) -> 440;
getCountry(<<"卢森堡"/utf8, _/binary>>) -> 442;
getCountry(<<"拉脱维亚"/utf8, _/binary>>) -> 428;
getCountry(<<"利比亚"/utf8, _/binary>>) -> 434;
getCountry(<<"摩洛哥"/utf8, _/binary>>) -> 504;
getCountry(<<"摩纳哥"/utf8, _/binary>>) -> 492;
getCountry(<<"摩尔多瓦"/utf8, _/binary>>) -> 498;
getCountry(<<"黑山"/utf8, _/binary>>) -> 499;
getCountry(<<"法属圣马丁"/utf8, _/binary>>) -> 663;
getCountry(<<"马达加斯加"/utf8, _/binary>>) -> 450;
getCountry(<<"马绍尔群岛"/utf8, _/binary>>) -> 584;
getCountry(<<"马其顿"/utf8, _/binary>>) -> 807;
getCountry(<<"马里"/utf8, _/binary>>) -> 466;
getCountry(<<"缅甸"/utf8, _/binary>>) -> 104;
getCountry(<<"蒙古"/utf8, _/binary>>) -> 496;
getCountry(<<"澳门"/utf8, _/binary>>) -> 446;
getCountry(<<"北马里亚纳群岛"/utf8, _/binary>>) -> 580;
getCountry(<<"马提尼克"/utf8, _/binary>>) -> 474;
getCountry(<<"毛里塔尼亚"/utf8, _/binary>>) -> 478;
getCountry(<<"蒙特塞拉特"/utf8, _/binary>>) -> 500;
getCountry(<<"马耳他"/utf8, _/binary>>) -> 470;
getCountry(<<"毛里求斯"/utf8, _/binary>>) -> 480;
getCountry(<<"马尔代夫"/utf8, _/binary>>) -> 462;
getCountry(<<"马拉维"/utf8, _/binary>>) -> 454;
getCountry(<<"墨西哥"/utf8, _/binary>>) -> 484;
getCountry(<<"马来西亚"/utf8, _/binary>>) -> 458;
getCountry(<<"莫桑比克"/utf8, _/binary>>) -> 508;
getCountry(<<"纳米比亚"/utf8, _/binary>>) -> 516;
getCountry(<<"新喀里多尼亚"/utf8, _/binary>>) -> 540;
getCountry(<<"尼日尔"/utf8, _/binary>>) -> 562;
getCountry(<<"诺福克岛"/utf8, _/binary>>) -> 574;
getCountry(<<"尼日利亚"/utf8, _/binary>>) -> 566;
getCountry(<<"尼加拉瓜"/utf8, _/binary>>) -> 558;
getCountry(<<"荷兰"/utf8, _/binary>>) -> 528;
getCountry(<<"挪威"/utf8, _/binary>>) -> 578;
getCountry(<<"尼泊尔"/utf8, _/binary>>) -> 524;
getCountry(<<"瑙鲁"/utf8, _/binary>>) -> 520;
getCountry(<<"纽埃"/utf8, _/binary>>) -> 570;
getCountry(<<"新西兰"/utf8, _/binary>>) -> 554;
getCountry(<<"阿曼"/utf8, _/binary>>) -> 512;
getCountry(<<"巴拿马"/utf8, _/binary>>) -> 591;
getCountry(<<"秘鲁"/utf8, _/binary>>) -> 604;
getCountry(<<"法属波利尼西亚"/utf8, _/binary>>) -> 258;
getCountry(<<"巴布亚新几内亚"/utf8, _/binary>>) -> 598;
getCountry(<<"菲律宾"/utf8, _/binary>>) -> 608;
getCountry(<<"巴基斯坦"/utf8, _/binary>>) -> 586;
getCountry(<<"波兰"/utf8, _/binary>>) -> 616;
getCountry(<<"圣皮埃尔和密克隆"/utf8, _/binary>>) -> 666;
getCountry(<<"皮特凯恩群岛"/utf8, _/binary>>) -> 612;
getCountry(<<"波多黎各"/utf8, _/binary>>) -> 630;
getCountry(<<"巴勒斯坦"/utf8, _/binary>>) -> 275;
getCountry(<<"葡萄牙"/utf8, _/binary>>) -> 620;
getCountry(<<"帕劳"/utf8, _/binary>>) -> 585;
getCountry(<<"巴拉圭"/utf8, _/binary>>) -> 600;
getCountry(<<"卡塔尔"/utf8, _/binary>>) -> 634;
getCountry(<<"留尼汪"/utf8, _/binary>>) -> 638;
getCountry(<<"罗马尼亚"/utf8, _/binary>>) -> 642;
getCountry(<<"塞尔维亚"/utf8, _/binary>>) -> 688;
getCountry(<<"俄罗斯"/utf8, _/binary>>) -> 643;
getCountry(<<"卢旺达"/utf8, _/binary>>) -> 646;
getCountry(<<"沙特阿拉伯"/utf8, _/binary>>) -> 682;
getCountry(<<"所罗门群岛"/utf8, _/binary>>) -> 90;
getCountry(<<"塞舌尔"/utf8, _/binary>>) -> 690;
getCountry(<<"苏丹"/utf8, _/binary>>) -> 729;
getCountry(<<"瑞典"/utf8, _/binary>>) -> 752;
getCountry(<<"新加坡"/utf8, _/binary>>) -> 702;
getCountry(<<"圣赫勒拿"/utf8, _/binary>>) -> 654;
getCountry(<<"斯洛文尼亚"/utf8, _/binary>>) -> 705;
getCountry(<<"挪威"/utf8, _/binary>>) -> 744;
getCountry(<<"斯洛伐克"/utf8, _/binary>>) -> 703;
getCountry(<<"塞拉利昂"/utf8, _/binary>>) -> 694;
getCountry(<<"圣马力诺"/utf8, _/binary>>) -> 674;
getCountry(<<"塞内加尔"/utf8, _/binary>>) -> 686;
getCountry(<<"索马里"/utf8, _/binary>>) -> 706;
getCountry(<<"苏里南"/utf8, _/binary>>) -> 740;
getCountry(<<"南苏丹"/utf8, _/binary>>) -> 728;
getCountry(<<"圣多美和普林西比"/utf8, _/binary>>) -> 678;
getCountry(<<"萨尔瓦多"/utf8, _/binary>>) -> 222;
getCountry(<<"荷属圣马丁"/utf8, _/binary>>) -> 534;
getCountry(<<"叙利亚"/utf8, _/binary>>) -> 760;
getCountry(<<"斯威士兰"/utf8, _/binary>>) -> 748;
getCountry(<<"特克斯和凯科斯群岛"/utf8, _/binary>>) -> 796;
getCountry(<<"乍得"/utf8, _/binary>>) -> 148;
getCountry(<<"法属南部领地"/utf8, _/binary>>) -> 260;
getCountry(<<"多哥"/utf8, _/binary>>) -> 768;
getCountry(<<"泰国"/utf8, _/binary>>) -> 764;
getCountry(<<"塔吉克斯坦"/utf8, _/binary>>) -> 762;
getCountry(<<"托克劳"/utf8, _/binary>>) -> 772;
getCountry(<<"东帝汶"/utf8, _/binary>>) -> 626;
getCountry(<<"土库曼斯坦"/utf8, _/binary>>) -> 795;
getCountry(<<"突尼斯"/utf8, _/binary>>) -> 788;
getCountry(<<"汤加"/utf8, _/binary>>) -> 776;
getCountry(<<"土耳其"/utf8, _/binary>>) -> 792;
getCountry(<<"特立尼达和多巴哥"/utf8, _/binary>>) -> 780;
getCountry(<<"图瓦卢"/utf8, _/binary>>) -> 798;
getCountry(<<"坦桑尼亚"/utf8, _/binary>>) -> 834;
getCountry(<<"乌克兰"/utf8, _/binary>>) -> 804;
getCountry(<<"乌干达"/utf8, _/binary>>) -> 800;
getCountry(<<"美国本土外小岛屿"/utf8, _/binary>>) -> 581;
getCountry(<<"乌拉圭"/utf8, _/binary>>) -> 858;
getCountry(<<"乌兹别克斯坦"/utf8, _/binary>>) -> 860;
getCountry(<<"梵蒂冈"/utf8, _/binary>>) -> 336;
getCountry(<<"圣文森特和格林纳丁斯"/utf8, _/binary>>) -> 670;
getCountry(<<"委内瑞拉"/utf8, _/binary>>) -> 862;
getCountry(<<"英属维尔京群岛"/utf8, _/binary>>) -> 92;
getCountry(<<"美属维尔京群岛"/utf8, _/binary>>) -> 850;
getCountry(<<"越南"/utf8, _/binary>>) -> 704;
getCountry(<<"瓦努阿图"/utf8, _/binary>>) -> 548;
getCountry(<<"瓦利斯和富图纳"/utf8, _/binary>>) -> 876;
getCountry(<<"萨摩亚"/utf8, _/binary>>) -> 882;
getCountry(<<"也门"/utf8, _/binary>>) -> 887;
getCountry(<<"马约特"/utf8, _/binary>>) -> 175;
getCountry(<<"南非"/utf8, _/binary>>) -> 710;
getCountry(<<"赞比亚"/utf8, _/binary>>) -> 894;
getCountry(<<"津巴布韦"/utf8, _/binary>>) -> 716;
getCountry(_) -> 999.


getProvince(<<"北京"/utf8, _/binary>>) ->
    1;
getProvince(<<"天津"/utf8, _/binary>>) ->
    2;
getProvince(<<"上海"/utf8, _/binary>>) ->
    3;
getProvince(<<"重庆"/utf8, _/binary>>) ->
    4;
getProvince(<<"河北"/utf8, _/binary>>) ->
    5;
getProvince(<<"河南"/utf8, _/binary>>) ->
    6;
getProvince(<<"云南"/utf8, _/binary>>) ->
    7;
getProvince(<<"辽宁"/utf8, _/binary>>) ->
    8;
getProvince(<<"黑龙江"/utf8, _/binary>>) ->
    9;
getProvince(<<"湖南"/utf8, _/binary>>) ->
    10;
getProvince(<<"湖北"/utf8, _/binary>>) ->
    11;
getProvince(<<"安徽"/utf8, _/binary>>) ->
    12;
getProvince(<<"山东"/utf8, _/binary>>) ->
    13;
getProvince(<<"新疆"/utf8, _/binary>>) ->
    15;
getProvince(<<"江苏"/utf8, _/binary>>) ->
    17;
getProvince(<<"江西"/utf8, _/binary>>) ->
    16;
getProvince(<<"浙江"/utf8, _/binary>>) ->
    18;
getProvince(<<"广西"/utf8, _/binary>>) ->
    19;
getProvince(<<"广东"/utf8,_/binary>>) ->
    20;
getProvince(<<"甘肃"/utf8, _/binary>>) ->
    21;
getProvince(<<"山西"/utf8, _/binary>>) ->
    14;
getProvince(<<"内蒙古"/utf8, _/binary>>) ->
    22;
getProvince(<<"陕西"/utf8, _/binary>>) ->
    23;
getProvince(<<"吉林"/utf8, _/binary>>) ->
    24;
getProvince(<<"福建"/utf8, _/binary>>) ->
    25;
getProvince(<<"贵州"/utf8, _/binary>>) ->
    26;
getProvince(<<"青海"/utf8, _/binary>>) ->
    28;
getProvince(<<"西藏"/utf8, _/binary>>) ->
    31;
getProvince(<<"四川"/utf8, _/binary>>) ->
    30;
getProvince(<<"宁夏"/utf8, _/binary>>) ->
    27;
getProvince(<<"海南"/utf8, _/binary>>) ->
    29;
getProvince(<<"台湾"/utf8, _/binary>>) ->
    32;
getProvince(<<"香港"/utf8, _/binary>>) ->
    33;
getProvince(<<"澳门"/utf8, _/binary>>) ->
    34;
getProvince(Address) ->
    CNAddress = unicode:characters_to_list(Address),
    ProvinceList = [
                 {"北京",1},
                 {"天津", 2}, 
                 {"重庆", 3},
                 {"上海", 4},
                 {"河北", 5}, 
                 {"河南", 6}, 
                 {"云南", 7},
                 {"辽宁", 8}, 
                 {"黑龙江", 9}, 
                 {"湖南", 10},
                 {"湖北", 11},
                 {"安徽", 12},
                 {"山东", 13},
                 {"山西", 14},
                 {"新疆", 15},
                 {"江西", 16},
                 {"江苏", 17},
                 {"浙江", 18},
                 {"广西", 19},
                 {"广东", 20},
                 {"甘肃", 21},
                 {"内蒙古", 22},
                 {"陕西", 23},
                 {"吉林", 24},
                 {"福建", 25},
                 {"贵州", 26},
                 {"宁夏", 27},
                 {"青海", 28},
                 {"海南", 29},
                 {"四川", 30},
                 {"西藏", 31},
                 {"台湾", 32},
                 {"香港", 33},
                 {"澳门", 34} 
               ],
    getProvince(normal, CNAddress, ProvinceList).

getProvince(normal, _, []) ->
    35;
getProvince(normal, Address, [{ProvinceT, ProvinceCode}|T]) ->
    IsProvince = isProvince(Address, ProvinceT),
    if 
        IsProvince ->
            ProvinceCode;
        true ->
            getProvince(normal, Address, T)
    end.

isProvince(Address, TestP) ->
    string:str(Address, TestP) > 0.


getProvinceName(1) ->
    "北京";
getProvinceName(2) ->
    "天津";
getProvinceName(3) ->
    "重庆";
getProvinceName(4) ->
    "上海";
getProvinceName(5) ->
    "河北";
getProvinceName(6) ->
    "河南";
getProvinceName(7) ->
    "云南";
getProvinceName(8) ->
    "辽宁";
getProvinceName(9) ->
    "黑龙江";
getProvinceName(10) ->
    "湖南";
getProvinceName(11) ->
    "湖北";
getProvinceName(12) ->
    "安徽";
getProvinceName(13) ->
    "山东";
getProvinceName(14) ->
    "山西";
getProvinceName(15) ->
    "新疆";
getProvinceName(16) ->
    "江西";
getProvinceName(17) ->
    "江苏";
getProvinceName(18) ->
    "浙江";
getProvinceName(19) ->
    "广西";
getProvinceName(20) ->
    "广东";
getProvinceName(21) ->
    "甘肃";
getProvinceName(22) ->
    "内蒙古";
getProvinceName(23) ->
    "陕西";
getProvinceName(24) ->
    "吉林";
getProvinceName(25) ->
    "福建";
getProvinceName(26) ->
    "贵州";
getProvinceName(27) ->
    "宁夏";
getProvinceName(28) ->
    "青海";
getProvinceName(29) ->
    "海南";
getProvinceName(30) ->
    "四川";
getProvinceName(31) ->
    "西藏";
getProvinceName(32) ->
    "台湾";
getProvinceName(33) ->
    "香港";
getProvinceName(34) ->
    "澳门";
getProvinceName(_) ->
    "喵星人".



































go() ->
    case file:consult(default_db('ip.txt')) of
        {error, Reason} ->
            io:format("~p~n", [Reason]);
        {ok, Data} -> 
            case file:open("log/ip_cn.txt", [append, {encoding, utf8}]) of
                {ok, IoDevice} ->
                    [IPL|_] = Data,
                    [ cnlocation(IP, IoDevice) || IP <- IPL ],
                    file:close(IoDevice);
                {error, R} ->
                    io:fomart("~p~n", [R])
            end
    end.

cnlocation(Ip,  IoDevice) ->
    Address = lookup(Ip),
    io:format(IoDevice, "~ts|~p~n", [Address, Ip]).

