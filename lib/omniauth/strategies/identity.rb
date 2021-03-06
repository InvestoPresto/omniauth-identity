module OmniAuth
  module Strategies
    # The identity strategy allows you to provide simple internal
    # user authentication using the same process flow that you
    # use for external OmniAuth providers.
    class Identity
      include OmniAuth::Strategy

      option :fields, [:name, :email, :password, :password_confirmation]
      option :on_failed_registration, nil
      option :custom_login_html, nil

      def request_form
        OmniAuth::Form.build(
          :title => (options[:title] || "Identity Verification"),
          :url => callback_path
        ) do |f|
          f.text_field 'Login', 'auth_key'
          f.password_field 'Password', 'password'
          f.html "<p align='center'><a href='#{registration_path}'>Create an Identity</a></p>"
          f.html options.custom_login_html if options.custom_login_html
        end
      end

      def request_phase
        request_form.to_response
      end

      def callback_phase
        return fail!(:invalid_credentials) unless identity
        super
      end

      def other_phase
        if on_registration_path?
          if request.get?
            registration_form
          elsif request.post?
            registration_phase
          end
        else
          call_app!
        end
      end

      def registration_form
        OmniAuth::Form.build(:title => 'Register Identity') do |f|
          options[:fields].each do |field|
            if field.match /password/
              f.password_field field.to_s.capitalize, field.to_s
            else
              f.text_field field.to_s.capitalize, field.to_s
            end
          end
        end.to_response
      end

      def registration_phase
        attributes = (options[:fields]).inject({}){|h,k| h[k] = request[k.to_s]; h}
        @identity = model.create(attributes)
        if @identity.persisted?
          env['PATH_INFO'] = callback_path
          callback_call
        else
          if options[:on_failed_registration]
            self.env['omniauth.identity'] = @identity
            options[:on_failed_registration].call(self.env)
          else
            registration_form
          end
        end
      end

      uid{ identity.uid }
      info{ identity.info }

      def registration_path
        options[:registration_path] || "#{path_prefix}/#{name}/register"
      end

      def on_registration_path?
        on_path?(registration_path)
      end

      def identity
        @identity ||= model.authenticate(request['auth_key'], request['password'])
      end

      def model
        options[:model] || ::Identity
      end
    end
  end
end
