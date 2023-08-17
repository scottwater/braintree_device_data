class CheckoutsController < ApplicationController
  TRANSACTION_SUCCESS_STATUSES = [
    Braintree::Transaction::Status::Authorizing,
    Braintree::Transaction::Status::Authorized,
    Braintree::Transaction::Status::Settled,
    Braintree::Transaction::Status::SettlementConfirmed,
    Braintree::Transaction::Status::SettlementPending,
    Braintree::Transaction::Status::Settling,
    Braintree::Transaction::Status::SubmittedForSettlement,
  ]

  def new
    @client_token = gateway.client_token.generate
  end

  def show
    @transaction = gateway.transaction.find(params[:id])
    @result = _create_result_hash(@transaction)
  end

  def create
    email = params["email"]
    nonce = params["payment_method_nonce"]
    device_data = params["device_data"]

    customer_data = {
      email: email,
      payment_method_nonce: nonce,
      device_data: device_data
    }

    customer_result = gateway.customer.create(customer_data)
    subscription_result = nil


    if customer_result.success?
      customer = customer_result.customer

      subscription_data = {
        payment_method_token: customer.default_payment_method.token,
        plan_id: :premium,
        price: 79,
        trial_duration: 0
      }

      subscription_result = @gateway.subscription.create(subscription_data)


    end


    if subscription_result&.success?

      redirect_to checkout_path(subscription_result.subscription.transactions.first.id)
    else
      error_result = subscription_result || customer_result
      error_messages = error_result&.errors&.map { |error| "Error: #{error.code}: #{error.message}" }
      flash[:error] = error_messages
      redirect_to new_checkout_path
    end
  end

  def _create_result_hash(transaction)
    status = transaction.status

    if TRANSACTION_SUCCESS_STATUSES.include? status
      result_hash = {
        :header => "Sweet Success!",
        :icon => "success",
        :message => "Your test transaction has been successfully processed. See the Braintree API response and try again."
      }
    else
      result_hash = {
        :header => "Transaction Failed",
        :icon => "fail",
        :message => "Your test transaction has a status of #{status}. See the Braintree API response and try again."
      }
    end
  end

  def gateway
    env = ENV["BT_ENVIRONMENT"]

    @gateway ||= Braintree::Gateway.new(
      :environment => env && env.to_sym,
      :merchant_id => ENV["BT_MERCHANT_ID"],
      :public_key => ENV["BT_PUBLIC_KEY"],
      :private_key => ENV["BT_PRIVATE_KEY"],
    )
  end
end
