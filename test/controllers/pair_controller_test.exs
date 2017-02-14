defmodule Pairmotron.PairControllerTest do
  use Pairmotron.ConnCase

  import Pairmotron.TestHelper,
    only: [log_in: 2, create_retro: 2, create_pair_and_retro: 2]

  describe "while authenticated" do
    setup do
      user = insert(:user)
      group = insert(:group, %{owner: user, users: [user]})
      conn = build_conn() |> log_in(user)
      {:ok, [conn: conn, logged_in_user: user, group: group]}
    end

    test "displays link to retro :create for a pair and current user with no retrospective",
      %{conn: conn, logged_in_user: user, group: group} do
      pair = Pairmotron.TestHelper.create_pair([user], group)
      conn = get(conn, "/pairs")
      assert html_response(conn, 200) =~ pair_retro_path(conn, :new, pair.id)
    end

    test "displays link to retro :create when the other user in pair has retro but current_user doesn't",
      %{conn: conn, logged_in_user: user, group: group} do
      other_user = insert(:user)
      pair = Pairmotron.TestHelper.create_pair([user, other_user], group)
      create_retro(other_user, pair)
      conn = get(conn, "/pairs")
      assert html_response(conn, 200) =~ pair_retro_path(conn, :new, pair.id)
    end

    test "displays link to retro :show for pair and current user with retrospective",
      %{conn: conn, logged_in_user: user, group: group} do
      {_pair, retro} = create_pair_and_retro(user, group)
      conn = get(conn, "/pairs")
      assert html_response(conn, 200) =~ pair_retro_path(conn, :show, retro.id)
    end

    test "displays link to retro :show for pair and current user with retrospective for :show",
      %{conn: conn, logged_in_user: user, group: group} do
      {year, week} = Timex.iso_week(Timex.today)
      pair = Pairmotron.TestHelper.create_pair([user], group, year, week)
      retro = create_retro(user, pair) # create_retro function defines pair_date as Timex.today
      conn = get conn, pair_path(conn, :show, year, week)
      assert html_response(conn, 200) =~ pair_retro_path(conn, :show, retro.id)
    end

    test "does not re-pair after the first pair has been made", %{conn: conn, logged_in_user: user, group: group} do
      Pairmotron.TestHelper.create_pair([user], group)
      new_user = insert(:user)
      conn = get(conn, "/pairs")
      assert html_response(conn, 200) =~ user.name
      refute html_response(conn, 200) =~ new_user.name
    end

    test "does not pairify for a week that is not current", %{conn: conn, logged_in_user: user} do
      conn = get conn, pair_path(conn, :show, 1999, 1)
      refute html_response(conn, 200) =~ user.name
    end

    test "displays each of the user's groups' pairs", %{conn: conn, logged_in_user: user, group: group} do
      {year, week} = Timex.iso_week(Timex.today)
      group2 = insert(:group, %{owner: user, users: [user]})
      Pairmotron.TestHelper.create_pair([user], group, year, week)
      Pairmotron.TestHelper.create_pair([user], group2, year, week)
      conn = get conn, pair_path(conn, :index)
      assert html_response(conn, 200) =~ group.name
      assert html_response(conn, 200) =~ group2.name
    end
  end
end
