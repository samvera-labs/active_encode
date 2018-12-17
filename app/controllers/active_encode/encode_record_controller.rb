module ActiveEncode
  class EncodeRecordController < ActionController::Base
    def show
      @encode_record = ActiveEncode::EncodeRecord.find(params[:id])
      respond_to do |format|
        format.any { render json: @encode_record.raw_object }
      end
    end
  end
end
