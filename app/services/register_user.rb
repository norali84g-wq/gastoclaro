class RegisterUser
  def self.call(params)
    user = User.new(params)
    user.admin = false
    user.family_group = FamilyGroup.new(name: "Personal - #{params[:user]}")
    user.save(context: :registration)
    user
  end
end
