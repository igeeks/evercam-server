defmodule EvercamMedia.PublicController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.PublicView

  @default_distance 1000
  @default_offset 0
  @default_limit 100
  @maximum_limit 1000

  def index(conn, params) do
    coordinates = parse_near_to(params["is_near_to"])
    within_distance = parse_distance(params["within_distance"])
    limit = parse_limit(params["limit"])
    offset = parse_offset(params["offset"])

    public_cameras_query = Camera.public_cameras_query(coordinates, within_distance)

    case geojson?(params["geojson"]) do
      false ->
        count = Camera.count(public_cameras_query)

        total_pages =
          count
          |> Kernel./(limit)
          |> Float.floor
          |> round
          |> if_zero

        cameras = Camera.get_query_with_associations(public_cameras_query, limit, offset)

        conn
        |> render(PublicView, "index.json", %{cameras: cameras, total_pages: total_pages, count: count})
      true ->
        geojson_cameras =
          public_cameras_query
          |> Camera.where_location_is_not_nil
          |> Camera.get_query_with_associations(limit, offset)

        conn
        |> render(PublicView, "cameras.json", %{geojson_cameras: geojson_cameras})
    end
  end

  defp parse_near_to(nil), do: {0, 0}
  defp parse_near_to(near_to) do
    case String.contains?(near_to, ",") do
      true ->
        near_to
        |> String.trim
        |> String.split(",")
        |> Enum.map(fn(x) -> string_to_float(x) end)
        |> List.to_tuple
      _ ->
        near_to
        |> fetch
    end
  end

  defp parse_distance(nil), do: @default_distance
  defp parse_distance(distance) do
    Float.parse(distance) |> elem(0)
  end

  defp parse_offset(nil), do: @default_offset
  defp parse_offset(offset) do
    offset = String.to_integer(offset)
    if offset >= 0 do
      offset
    else
      @default_offset
    end
  end

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(limit) do
    limit = String.to_integer(limit)
    if limit > @maximum_limit do
      @maximum_limit
    else
      limit
    end
  end

  defp if_zero(total_pages) when total_pages <= 0, do: 1
  defp if_zero(total_pages), do: total_pages

  defp string_to_float(string), do: string |> Float.parse |> elem(0)

  defp geojson?(nil), do: false
  defp geojson?(geojson) do
    case String.equivalent?(geojson, "true") do
      true -> true
      false -> false
    end
  end

  def fetch(address) do
    "http://maps.googleapis.com/maps/api/geocode/json?address=" <> URI.encode(address)
    |> HTTPotion.get
    |> Map.get(:body)
    |> Poison.decode!
    |> get_in(["results", Access.at(0), "geometry", "location"])
    |> Enum.map(fn({_coordinate, value}) -> value end)
    |> List.to_tuple
  end
end
