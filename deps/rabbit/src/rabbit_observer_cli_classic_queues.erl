%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2007-2021 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(rabbit_observer_cli_classic_queues).

-export([plugin_info/0]).
-export([attributes/1, sheet_header/0, sheet_body/1]).

-include_lib("rabbit_common/include/rabbit.hrl").

plugin_info() ->
    #{
        module => rabbit_observer_cli_classic_queues,
        title => "Classic Q",
        shortcut => "CQ",
        sort_column => 4
    }.

attributes(State) ->
    {[
        [#{content => "Q: MQ+GQ. MQ: Mailbox. GQ: GS2 internal mailbox."
                      "(o)h(b)s: (old) heap (block) size. ms: Mailbox buffer size.",
           width => 136}]
    ], State}.

sheet_header() ->
    [
        #{title => "Pid", width => 12, shortcut => "P"},
        #{title => "Vhost", width => 10, shortcut => "V"},
        #{title => "Name", width => 26, shortcut => "N"},
        #{title => "Memory", width => 12, shortcut => "M"},
        #{title => "", width => 5, shortcut => "Q"},
        #{title => "", width => 5, shortcut => "MQ"},
        #{title => "", width => 5, shortcut => "GQ"},
        #{title => "", width => 10, shortcut => "hs"},
        #{title => "", width => 10, shortcut => "hbs"},
        #{title => "", width => 10, shortcut => "ohs"},
        #{title => "", width => 10, shortcut => "ohbs"},
        #{title => "", width => 10, shortcut => "ms"}
    ].

sheet_body(State) ->
    Body = [begin
        #resource{name = Name, virtual_host = Vhost} = amqqueue:get_name(Q),
        case rabbit_amqqueue:pid_of(Q) of
            {error, not_found} ->
                ["dead", Vhost, Name];
            Pid ->
                case process_info(Pid, [memory, message_queue_len, garbage_collection_info]) of
                    undefined ->
                        [pid_to_list(Pid) ++ " (dead)", Vhost, Name];
                    InfoList ->
                        [
                            {memory, Mem},
                            {message_queue_len, MsgQ},
                            {garbage_collection_info, GCI}
                        ] = InfoList,
                        GS2Q = rabbit_core_metrics:get_gen_server2_stats(Pid),
                        [
                            Pid, Vhost, Name,
                            Mem,
                            MsgQ + GS2Q, MsgQ, GS2Q,
                            proplists:get_value(heap_size, GCI),
                            proplists:get_value(heap_block_size, GCI),
                            proplists:get_value(old_heap_size, GCI),
                            proplists:get_value(old_heap_block_size, GCI),
                            proplists:get_value(mbuf_size, GCI)
                        ]
                end
        end
    end || Q <- rabbit_amqqueue:list_by_type(classic)],
    {Body, State}.
