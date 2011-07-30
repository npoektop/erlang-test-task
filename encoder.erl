%% erlang solution for http://www.flownet.com/ron/papers/lisp-java/
-module(encoder).
-export([main/0]). 
%% -compile([debug_info, export_all]).

-record(dict, {number, word}).

main() ->
    initialize(), 
    prepare_dict("dictionary.txt"),
    encode_from_file("input.txt"),
    tear_down().

encode_from_file(Filename) ->
    {ok, File} = file:open(Filename, [read]),
    try encode_from_file_loop(File)
      after file:close(File)
    end.

encode_from_file_loop(File) ->
    case io:get_line(File, "") of
        eof  -> ok;   % TODO: proper error check
        Line -> 
            try 
                Trimmed = string:strip(Line),
                Number = string:substr(Trimmed, 1, string:len(Trimmed)-1),   % get_line includes LF or EOF at the end
                encode(Number)
            catch bad_symbol_in_number -> skip_this_number
                                              % TODO: log it
            end,
            encode_from_file_loop(File)
    end.
    

initialize () ->
    mnesia:start(),
    mnesia:create_table(dict, [{type, bag}, 
                                     {attributes, record_info(fields, dict)}]).

tear_down () -> do_nothing.
%% i don't know how to supress it's output so i'll just skip this
%% maybe i'll rewrite it later 
%% TODO: write output directly to file
    %% mnesia:stop().

prepare_dict(Filename) ->
    {ok, File} = file:open(Filename, [read]),
    try read_words_from_file(File)
      after file:close(File)
    end.

read_words_from_file(File) ->
    case io:get_line(File, "") of
        eof  -> ok;   % TODO: proper error check
        Line -> Trimmed = string:strip(Line),
                Word = string:substr ( Trimmed, 1, string:len(Trimmed) - 1 ),   % get_line includes LF or EOF at the end
                add_to_dict(Word),
                read_words_from_file(File)
    end.



%% words like -"-"- will be mapped to [] number and saved to base as []:[]
%% we only look for non-empty number strings, so skip this check
add_to_dict (Word) ->
    try
        Fun = fun() -> mnesia:write(#dict{number=word_to_number(Word), word=Word}) end,    
        mnesia:transaction(Fun)
    catch
        bad_symbol_in_word -> skip_this_word
                              %% TODO: log it
    end.

number_to_words (Number) ->
    Fun = fun() -> mnesia:read({dict, Number}) end,
    {atomic, Results} = mnesia:transaction(Fun),
    List = [B || {_, _, B} <- Results],
    List.

%% was like that, but i decided to skip bad words
%% word_to_number (Word) ->
%%     Symbol = string:to_lower(Word),
%%     [char_to_number(C) || C <- Symbol, $a =< C, C =< $z].   % important check
word_to_number ([]) -> [];
word_to_number ([Head|Tail]) ->
    H = string:to_lower(Head),
    if $a =< H, H =< $z -> Symbol = [char_to_number(H)];
       H == $"; H == $- -> Symbol = [];
       true -> Symbol = [], 
               throw(bad_symbol_in_word)
    end,
    Symbol ++ word_to_number(Tail).

strip_line_to_number([]) -> [];
strip_line_to_number([H|T]) ->
    if $0 =<H, H=<$9 -> Symbol = [H];
       H == $-; H == $/ -> Symbol = [];
       true -> Symbol = [],
            throw(bad_symbol_in_number)
    end,
    Symbol ++ strip_line_to_number(T).




%% e | j n q | r w x | d s y | f t | a m | c i v | b k u | l o p | g h z
%% 0 |   1   |   2   |   3   |  4  |  5  |   6   |   7   |   8   |   9
char_to_number ($e) -> $0;
char_to_number ($j) -> $1;
char_to_number ($n) -> $1;
char_to_number ($q) -> $1;
char_to_number ($r) -> $2;
char_to_number ($w) -> $2;
char_to_number ($x) -> $2;
char_to_number ($d) -> $3;
char_to_number ($s) -> $3;
char_to_number ($y) -> $3;
char_to_number ($f) -> $4;
char_to_number ($t) -> $4;
char_to_number ($a) -> $5;
char_to_number ($m) -> $5;
char_to_number ($c) -> $6;
char_to_number ($i) -> $6;
char_to_number ($v) -> $6;
char_to_number ($b) -> $7;
char_to_number ($k) -> $7;
char_to_number ($u) -> $7;
char_to_number ($l) -> $8;
char_to_number ($o) -> $8;
char_to_number ($p) -> $8;
char_to_number ($g) -> $9;
char_to_number ($h) -> $9;
char_to_number ($z) -> $9.


            
%% interpose(["a", "b", "c"], ", ") -> "a, b, c"
interpose(StrList) -> interpose(StrList, " ").
interpose([], _) -> [];
interpose([H], _) -> H;
interpose([H|T], Delimiter) -> H ++ Delimiter ++ interpose(T, Delimiter).





encode(Number) -> 
    Stripped = strip_line_to_number(Number),
    encode(Number, Stripped, string:len(Stripped), 1, []).
encode(Number, Stripped, Length, Position, Words) ->
    if Position > Length ->  io:format("~s: ~s~n", [Number, interpose(lists:reverse(Words))]), true;
       true -> 
            FoundWord = encode_loop(1, Length-Position+1, Number, Stripped, Length, Position, Words),
            FirstWordIsDigit = first_word_is_digit(Words),
            D = string:substr(Stripped, Position, 1),
            if FoundWord and not(FirstWordIsDigit) ->
                    encode(Number, Stripped, Length, Position+1, [D]++Words);
               true -> ok
            end
    end.

%% for i=1; i=< Length-Position+1
%%   get words for number(start, i)
%%   foreach word in words
%%      encode(Number, Stripped, Position+i, Length, [word]++Words)
%% return true if found word
encode_loop(I, End, Number, Stripped, Length, Position, Words) ->
    if I > End -> true;
       true ->
            Subnum = string:substr(Stripped, Position, I),
            List = number_to_words(Subnum),
            lists:foreach(fun(W)-> encode(Number, Stripped, Length, Position+I, [W]++Words) end, List),
            %% TODO: ain't tail recursion. Rewrite using fold.
            (List =:= []) and encode_loop(I+1, End, Number, Stripped, Length, Position, Words)
    end.

% i mean last in reversed words list
first_word_is_digit([[D]|_]) -> ($0=<D) and (D=<$9);
first_word_is_digit(_) -> false.





