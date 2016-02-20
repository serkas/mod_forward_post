-module(mod_forward_post).

-behaviour(gen_mod).


%% Required by ?INFO_MSG macros
-include("logger.hrl").

-include("jlib.hrl").

%% gen_mod API callbacks
-export([start/2, stop/1]).

-export([on_message/4]).

start(Host, _Opts) ->
  ejabberd_hooks:add(user_send_packet, Host, ?MODULE, on_message, 50),
  ?INFO_MSG("Module mod_forward_post started! Opts: ~p", [_Opts]),
  ok.

stop(_Host) ->
  ?INFO_MSG("Module mod_forward_post stopped!", []),
  ok.

on_message(Packet, _C2SState, From, To) ->
  #xmlel{name = Name, children = Elements} = Packet,
  case Name of
    <<"message">> ->
      case fxml:get_tag_attr_s(<<"type">>, Packet) of
        <<"chat">> -> handle_message(From, To, "chat", Elements);
        <<"groupchat">> -> handle_message(From, To, "groupchat", Elements);
        _ -> ok
      end;
    _ -> ok
  end,
  Packet.

handle_message(From, To, Type, Elements) ->
  UTo = binary_to_list(To#jid.luser),
  UFrom = binary_to_list(From#jid.luser),

  MessageData = get_message_payload(Elements),

  Validate = fun(A) when is_binary(A) -> binary_to_list(A) end,
  Uri = gen_mod:get_module_opt(From#jid.lserver, ?MODULE, uri, Validate, "http://localhost:9998/"),

  case MessageData of
    [] -> ok;
    _ ->
      Data = fold_attributes([{"from", UFrom}, {"to", UTo}, {"type", Type} | MessageData]),
      send_data(Uri, Data)
  end.


get_message_payload(Elements) ->
  get_message_payload(Elements, []).

get_message_payload([], Acc) ->
  lists:filter(fun({_, Value}) -> Value /= empty end, Acc);


get_message_payload([Elem | Elements], Acc) ->
  case Elem of
    #xmlel{children = BodyParts, name = <<"body">>} ->
      get_message_payload(Elements, [{"body_text", get_body_text(BodyParts)} | Acc]);
    #xmlel{name = <<"media">>} ->
      get_message_payload(Elements, Acc ++ get_media_attrs(Elem));
    _ -> get_message_payload(Elements, Acc)
  end.


get_body_text(BodyParts) ->
  case BodyParts of
    [{xmlcdata, Text} | _] -> binary_to_list(Text);
    _ -> empty
  end.

get_media_attrs(Elem) ->
  Type = fxml:get_tag_attr_s(<<"type">>, Elem),
  Uri = fxml:get_tag_attr_s(<<"uri">>, Elem),
  Thumbnail = fxml:get_tag_attr_s(<<"thumbnail">>, Elem),
  [{"media_type", binary_to_list(Type)}, {"media_uri", binary_to_list(Uri)}, {"media_tn", binary_to_list(Thumbnail)}].

send_data(Uri, Data) ->
  ?INFO_MSG("Posting. Payload ~p~n", [Data]),
  httpc:request(post, {Uri, [],
    "application/x-www-form-urlencoded", Data}, [], []),
  ?INFO_MSG("post request sent", []),
  ok.

fold_attributes(Data) -> fold_attributes(Data, []).

fold_attributes([], Acc) -> Acc;
fold_attributes([{Name, Value} | Data], Acc) ->
  case Acc of
    [] -> fold_attributes(Data, lists:concat([Name, "=", Value]));
    _ -> fold_attributes(Data, lists:concat([Name, "=", Value, "&", Acc]))
  end.
