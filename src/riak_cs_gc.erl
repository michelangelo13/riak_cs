%% -------------------------------------------------------------------
%%
%% Copyright (c) 2007-2012 Basho Technologies, Inc.  All Rights Reserved.
%%
%% -------------------------------------------------------------------

%% @doc Utility module for garbage collection of files.

-module(riak_cs_gc).

-include("riak_moss.hrl").
-ifdef(TEST).
-compile(export_all).
-include_lib("eunit/include/eunit.hrl").
-endif.

%% export Public API
-export([delete_tombstone_time/0,
         schedule_manifests/2,
         timestamp/0]).

%%%===================================================================
%%% Public API
%%%===================================================================

%% @doc Return the minimum number of seconds a file manifest waits in
%% the `deleted' state before being removed from the file record.
-spec delete_tombstone_time() -> non_neg_integer().
delete_tombstone_time() ->
    case application:get_env(riak_moss, delete_tombstone_time) of
        undefined ->
            ?DEFAULT_DELETE_TOMBSTONE_TIME;
        {ok, TombstoneTime} ->
            TombstoneTime
    end.

%% @doc Copy data for a list of manifests to the
%% `riak-cs-gc' bucket to schedule them for deletion.
-spec schedule_manifests([lfs_manifest()], pid()) -> ok | {error, term()}.
schedule_manifests(Manifests, RiakPid) ->
    %% Create a set from the list of manifests
    ManifestSet = build_manifest_set(twop_set:new(), Manifests),
    _ = lager:debug("Manifests scheduled for deletion: ~p", [ManifestSet]),
    %% Write the set to a timestamped key in the `riak-cs-gc' bucket
    Key = generate_key(),
    RiakObject = riakc_obj:new(?GC_BUCKET, Key, term_to_binary(ManifestSet)),
    riakc_pb_socket:put(RiakPid, RiakObject).

%% @doc Generate a key for storing a set of manifests for deletion.
timestamp() ->
    {MegaSecs, Secs, _MicroSecs} = erlang:now(),
    (MegaSecs * 1000000) + Secs.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec build_manifest_set(twop_set:twop_set(), [lfs_manifest()]) -> twop_set:twop_set().
build_manifest_set(Set, []) ->
    Set;
build_manifest_set(Set, [HeadManifest | RestManifests]) ->
    UpdSet = twop_set:add_element(HeadManifest, Set),
    build_manifest_set(UpdSet, RestManifests).

%% @doc Generate a key for storing a set of manifests in the
%% garbage collection bucket.
-spec generate_key() -> non_neg_integer().
generate_key() ->
    timestamp() + leeway_seconds().

%% @doc Return the minimum number of seconds a file manifest waits in
%% the `scheduled_delete' state before being garbage collected.
-spec leeway_seconds() -> non_neg_integer().
leeway_seconds() ->
    case application:get_env(riak_moss, leeway_seconds) of
        undefined ->
            ?DEFAULT_LEEWAY_SECONDS;
        {ok, LeewaySeconds} ->
            LeewaySeconds
    end.

%% ===================================================================
%% EUnit tests
%% ===================================================================
-ifdef(TEST).

-endif.