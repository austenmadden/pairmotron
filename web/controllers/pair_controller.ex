defmodule Pairmotron.PairController do
  use Pairmotron.Web, :controller

  alias Pairmotron.Pair
  alias Pairmotron.PairRetro
  alias Pairmotron.User
  alias Pairmotron.UserPair
  alias Pairmotron.Mixer
  alias Pairmotron.Pairer

  def index(conn, _params) do
    {year, week} = Timex.iso_week(Timex.today)
    pairs = fetch_or_gen(year, week)
    conn = assign_current_user_pair_retro_for_week(conn, year, week)
    render conn, "index.html", pairs: pairs, year: year, week: week
  end

  def show(conn, %{"year" => y, "week" => w}) do
    {year, _} = y |> Integer.parse
    {week, _} = w |> Integer.parse
    pairs = fetch_or_gen(year, week)
    conn = assign_current_user_pair_retro_for_week(conn, year, week)
    render conn, "index.html", pairs: pairs, year: year, week: week
  end

  def delete(conn, %{"year" => y, "week" => w}) do
    {year, _} = y |> Integer.parse
    {week, _} = w |> Integer.parse
    fetch_pairs(year, week)
      |> Enum.map(fn(p) -> Repo.delete! p end)
    conn
      |> put_flash(:info, "Repairified")
      |> redirect(to: pair_path(conn, :show, year, week))
  end

  defp fetch_or_gen(year, week) do
    case fetch_pairs(year, week) do
      []    -> generate_and_fetch_if_current_week(year, week)
      pairs -> pairs
    end
      |> fetch_users_from_pairs
  end

  defp generate_and_fetch_if_current_week(year, week) do
    case Pairmotron.Calendar.same_week?(year, week, Timex.today) do
      true ->
        generate_pairs(year, week)
        fetch_pairs(year, week)
      false -> []
    end
  end

  defp fetch_pairs(year, week) do
    Pair
      |> where(year: ^year, week: ^week)
      |> order_by(:id)
      |> Repo.all
  end

  defp fetch_users_from_pairs(pairs) do
    pairs
      |> Repo.preload([:users])
  end

  defp generate_pairs(year, week) do
    User.active_users
      |> order_by(:id)
      |> Repo.all
      |> Mixer.mixify(week)
      |> Pairer.generate_pairs
      |> Enum.map(fn(users) -> make_pairs(users, year, week) end)
      |> List.flatten
      |> Enum.map(fn(p) -> Repo.insert! p end)
  end

  defp make_pairs(users, year, week) do
    pair = Repo.insert! Pair.changeset(%Pair{}, %{year: year, week: week})
    users
      |> Enum.map(fn(user) -> UserPair.changeset(%UserPair{}, %{pair_id: pair.id, user_id: user.id}) end)
  end

  defp assign_current_user_pair_retro_for_week(conn, year, week) do
    current_user = conn.assigns[:current_user]
    retro = Repo.one(PairRetro.retro_for_user_and_week(current_user, year, week))
    Plug.Conn.assign(conn, :current_user_retro_for_week, retro)
  end
end