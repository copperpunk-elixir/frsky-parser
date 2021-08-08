defmodule FrskyParser do
  require Logger
  use Bitwise

  @moduledoc """
  Parse and store SBus packets coming from FrSky receiver.
  """

  @pw_mid 991
  @pw_half_range 819

  @start_byte 0x0F
  @end_byte 0x00
  @payload_length 24

  @doc false
  defstruct parser_state: 0,
            prev_byte: 0,
            payload_rev: [],
            payload_ready: false,
            channels: [],
            remaining_data: []

  # Public API
  @doc """
  Create a new FrskyParser struct that can parse new serial data and
  store the most recently received RX output.
  """
  @spec new() :: struct()
  def new() do
    %FrskyParser{}
  end

  @doc """
  Appends the latest data to any leftover data from the previous `check_for_new_messages` operation.

  Arguments are the `%FrskyParser{}` struct and the newest serial data from the receiver (must already by converted from binary to list)

  Returns `{%FrskyParser{}, [list of channels]}`. If no valid SBus messages was found, the list of channels will be empty.

  NOTE: After a valid message has been received, the `clear` function must be called if you do not want the channel values to persist.
  Otherwise this function will continue to return a populated channel list even if a new valid message has not been received.

  Example:
  ```
  {frsky_parser, channel_values} = FrskyParser.check_for_new_messages(frsky_parser, new_data_list)
  frsky_parser = FrskyParser.clear()
  ```
  """

  @spec check_for_new_messages(struct(), list()) :: tuple()
  def check_for_new_messages(frsky, data) do
    frsky = parse_data(frsky, data)

    if frsky.payload_ready do
      {frsky, frsky.channels}
    else
      {frsky, []}
    end
  end

  @doc false
  @spec parse_data(struct(), list()) :: struct()
  def parse_data(frsky, data) do
    data = frsky.remaining_data ++ data

    if Enum.empty?(data) do
      frsky
    else
      {[byte], remaining_data} = Enum.split(data, 1)
      frsky = parse_byte(frsky, byte)

      cond do
        frsky.payload_ready -> %{frsky | remaining_data: remaining_data}
        Enum.empty?(remaining_data) -> %{frsky | remaining_data: []}
        true -> parse_data(%{frsky | remaining_data: []}, remaining_data)
      end
    end
  end

  @doc false
  @spec parse_byte(struct(), integer()) :: struct()
  def parse_byte(frsky, byte) do
    parser_state = frsky.parser_state

    frsky =
      if parser_state == 0 do
        if byte == @start_byte and frsky.prev_byte == @end_byte do
          %{frsky | parser_state: parser_state + 1, payload_rev: []}
        else
          frsky
        end
      else
        {parser_state, payload_rev} =
          if parser_state - 1 < @payload_length do
            payload_rev = [byte] ++ frsky.payload_rev
            {parser_state + 1, payload_rev}
          else
            {parser_state, frsky.payload_rev}
          end

        if parser_state - 1 == @payload_length do
          if byte == @end_byte do
            parse_payload(frsky, payload_rev)
            |> Map.put(:parser_state, 0)
          else
            %{frsky | parser_state: 0}
          end
        else
          %{frsky | parser_state: parser_state, payload_rev: payload_rev}
        end
      end

    %{frsky | prev_byte: byte}
  end

  @doc false
  @spec parse_payload(struct(), list()) :: struct()
  def parse_payload(frsky, payload_rev) do
    payload = Enum.reverse(payload_rev)

    channels = [
      Enum.at(payload, 0) + (Enum.at(payload, 1) <<< 8),
      (Enum.at(payload, 1) >>> 3) + (Enum.at(payload, 2) <<< 5),
      (Enum.at(payload, 2) >>> 6) + (Enum.at(payload, 3) <<< 2) + (Enum.at(payload, 4) <<< 10),
      (Enum.at(payload, 4) >>> 1) + (Enum.at(payload, 5) <<< 7),
      (Enum.at(payload, 5) >>> 4) + (Enum.at(payload, 6) <<< 4),
      (Enum.at(payload, 6) >>> 7) + (Enum.at(payload, 7) <<< 1) + (Enum.at(payload, 8) <<< 9),
      (Enum.at(payload, 8) >>> 2) + (Enum.at(payload, 9) <<< 6),
      (Enum.at(payload, 9) >>> 5) + (Enum.at(payload, 10) <<< 3),
      Enum.at(payload, 11) + (Enum.at(payload, 12) <<< 8),
      (Enum.at(payload, 12) >>> 3) + (Enum.at(payload, 13) <<< 5),
      (Enum.at(payload, 13) >>> 6) + (Enum.at(payload, 14) <<< 2) + (Enum.at(payload, 15) <<< 10),
      (Enum.at(payload, 15) >>> 1) + (Enum.at(payload, 16) <<< 7),
      (Enum.at(payload, 16) >>> 4) + (Enum.at(payload, 17) <<< 4),
      (Enum.at(payload, 17) >>> 7) + (Enum.at(payload, 18) <<< 1) + (Enum.at(payload, 19) <<< 9),
      (Enum.at(payload, 19) >>> 2) + (Enum.at(payload, 20) <<< 6),
      (Enum.at(payload, 20) >>> 5) + (Enum.at(payload, 21) <<< 3)
    ]

    channels =
      Enum.reduce(Enum.reverse(channels), [], fn value, acc ->
        # [(value &&& 0x07FF)] ++ acc
        value_float = constrain(((value &&& 0x07FF) - @pw_mid) / @pw_half_range, -1.0, 1.0)

        [value_float] ++ acc
      end)

    flag_byte = Enum.at(payload, 22)
    # failsafe_active = ((flag_byte &&& 0x08) > 0)
    frame_lost = (flag_byte &&& 0x04) > 0
    %{frsky | payload_ready: !frame_lost, channels: channels}
  end

  @doc """
  Returns the stored channel values.
  """
  @spec channels(struct()) :: list()
  def channels(frsky) do
    frsky.channels
  end

  @doc """
  Empties the stored channel value list.
  """
  @spec clear(struct()) :: struct()
  def clear(frsky) do
    %{frsky | payload_ready: false}
  end

  @doc false
  @spec constrain(number(), number(), number()) :: number()
  def constrain(x, min_value, max_value) do
    case x do
      _ when x > max_value -> max_value
      _ when x < min_value -> min_value
      x -> x
    end
  end
end
