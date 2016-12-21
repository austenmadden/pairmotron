defimpl Canada.Can, for: Pairmotron.User do
  alias Pairmotron.{PairRetro, User}

  def can?(%User{id: user_id}, action, %PairRetro{user_id: user_id})
    when action in [:edit, :update, :show, :delete], do: true

  def can?(%User{}, _, _), do: false
end
