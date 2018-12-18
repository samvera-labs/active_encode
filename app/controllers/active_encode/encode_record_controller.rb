module ActiveEncode
  class EncodeRecordController < ActionController::Base
    def show
      @encode_record = ActiveEncode::EncodeRecord.find(params[:id])
      render json: @encode_record.raw_object
    end
  end
end
