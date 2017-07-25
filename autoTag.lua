--[[

===============================================================

					autoTag

	Contain main function
	Send thumbnail files to server

					
===============================================================]]


-- Access the Lightroom SDK namespaces.
local LrView = import "LrView"    ---  for testing
local LrHttp = import "LrHttp"
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'
local LrStringUtils = import  'LrStringUtils'
local prefs = import "LrPrefs".prefsForPlugin()

--	json.lua
local json = require("json")


-- Set Params from LrPrefs
local GOOGLE_API_KEY =	prefs.google_key 
local IMAGGA_API_KEY =  prefs.imagga_key
local THUMBNAIL_SIZE = 1000				--	the tagging image width and height
local GOOGLE_MAX_RESULTS = 50			--	max results request per detection type 
local IMAGGA_MAX_RESULTS = 50			--	max results request per detection type
local MAX_KEYWORDS = 50					--	limited max keywords will add to image file
local GOOGLE_FEATURE_TYPE = { 'LABEL_DETECTION' }		-- contain enable detection type
local IMAGGA_FEATURE_TYPE = 'tagging' 				-- contain enable detection type


--	Set Constant
local URL_GOOGLE = 'https://vision.googleapis.com/v1/images:annotate?key='
local URL_IMAGGA = 'https://api.imagga.com/v1/'

--	Set	Error String
local is_error = false
local ERROR_CANNOT_CONNECT_TO_GOOGLE_SERVER = 'Cannot connect to Google server'
local ERROR_CANNOT_CONNECT_TO_IMAGGA_SERVER = 'Cannot connect to Imagga server'
local ERROR_FAILED_TO_UPLOAD_FILE_TO_IMAGGA = 'Failed to upload a photo to Imagga'
local ERROR_IMAGGA_PROCRSSING_IMAGE_UNSUCCESSFUL = 'Imagga : Processing image unsuccessful'
local ERROR_SCRIPT_HAS_STOP_WORKING = 'Script has stop working'
local ERROR_REQUIRE_API_KEY = 'Require Google or Imagga API Key to run this task'





--	prepare google_feature_type_json
local function google_feature_type_json()
	local value = ''
	foreach(GOOGLE_FEATURE_TYPE,function(key)
		value =	'{'..
			'"type":"' .. GOOGLE_FEATURE_TYPE[key] .. '",'..
			'"max_results":' .. GOOGLE_MAX_RESULTS ..
		'}'
	end)
	return value
end


--  prepare_google_postbody
--	@thumb_base64  thumbnail picture that was encode
local function prepare_google_postbody(thumb_base64)
	return '{'..
		'"requests":'..
			'['..
				'{'..
					'"image":'..
						'{"content":"'  .. thumb_base64 .. '"},' ..
					'"features":'..
						'['..
							google_feature_type_json() ..
						']'..
				'}'..
			']'..
	'}'
end



--[[------		foreach			---------	
	@_table
	@_function(@key)			call back function
		@key 					table key
------------------------------------------------]]
function foreach(_table,_function)
	local key = 1
	while _table[key]  do
		if _function(key) == false then
			break
		end
		key = key+1
	end
end



--[[------		createErrorDialog			---------
	display error 
------------------------------------------------]]
local function createErrorDialog(error_string)
	LrDialogs.showError(error_string)
end


--[[------		google_request			---------
	Send reuest to server and check response
	Return table
		{
			{
				"mid": Opaque entity ID(string) ,
				"description" :  Description(String),
				"score" : Confidence score(number:0-1),
			}
		}
	Return false and create error dialog if error
------------------------------------------------]]	
local function google_request(targetPhoto,data)

	--	prepare request
	local thumb_base64 = LrStringUtils.encodeBase64(data)
	local url = URL_GOOGLE .. GOOGLE_API_KEY
	local header = { contentType = 'application/json',}
	local postBody = prepare_google_postbody(thumb_base64)

	
	--	send request
	local response = LrHttp.post(url,postBody,header)
	
	--	if cannot get response create error dialog and stop working
	if	response == nil then
		createErrorDialog(ERROR_CANNOT_CONNECT_TO_GOOGLE_SERVER)
		is_error = true
		return false
	end

	
	--	parse json
	local response_json = json.parse(response)

	
	--	if get error response create error dialog and stop working
	if	(type(response_json["error"]) == 'table') then
		createErrorDialog(response)
		is_error = true
		return false
	end
	
	return response_json['responses'][1]["labelAnnotations"]
end



--	upload a photo to imagga and return id 
local function upload_photo_to_imagga(data)

	--	prepare request to upload image
	local url = URL_IMAGGA .. 'content'
	local header = { {field = 'Authorization', value = IMAGGA_API_KEY } }
	local postBody = {
			{
				name = 'image',
				fileName = 'photo.png',			
				value = data,
				contentType = "image/png",
			},
			
		}
	
	--	send request
	local response = LrHttp.postMultipart(url,postBody,header)
	
	--	if cannot get response create error dialog and stop working
	if	response == nil then
		createErrorDialog(ERROR_CANNOT_CONNECT_TO_IMAGGA_SERVER)
		is_error = true
		return false
	end

	--	parse json
	local response_json = json.parse(response)
	
	--	check upload status if fail create error dialog and stop working
	if	response_json["status"] ~= "success"  then
		createErrorDialog(ERROR_FAILED_TO_UPLOAD_FILE_TO_IMAGGA .. '\r' .. response)
		is_error = true
		return false
	end
	return  response_json["uploaded"][1]["id"]
end



--[[------		imagga_request			---------
	Upload thumbnail to server
	Get photo keywords
	Return table
		{
			{
				"tag" :  Description(String),
				"confidence" : Confidence score(number:0-1),
			}
		}
	Return false and create error dialog if error
------------------------------------------------]]	
local function imagga_request(targetPhoto,data)

	
	--	get a photo id
	local	photoId = upload_photo_to_imagga(data)
	if photoId == false then
		return false
	end
	
	--	prepare request to get keywords
	local url = URL_IMAGGA .. IMAGGA_FEATURE_TYPE .. "?content=" .. photoId
	local header = {
		{field = 'Authorization', value = IMAGGA_API_KEY } ,
		
	}
	
	--	send request
	local response = LrHttp.get(url,header)
	
	
	--	if cannot get response create error dialog and stop working
	if	response == nil then
		createErrorDialog(ERROR_CANNOT_CONNECT_TO_IMAGGA_SERVER)
		is_error = true
		return false
	end
	
		--	parse json
	local response_json = json.parse(response)

	
	--	if get error response create error dialog and stop working
	if	response_json["results"] == nil then
		createErrorDialog(ERROR_IMAGGA_PROCRSSING_IMAGE_UNSUCCESSFUL.. '\r' .. response)
		is_error = true
		return false
	end
	
	return response_json['results'][1]["tags"]
end


--[[------		addKeywordsToPhoto			---------
	Create Keywords and add it to photo
------------------------------------------------]]
local function addKeywordsToPhoto(targetPhoto,_response,tag_key)
	local	activeCat = targetPhoto.catalog
	activeCat:withWriteAccessDo('Add Keywords',function(context)
	
		foreach( _response , function(key)
			local keyword = activeCat:createKeyword(_response[key][tag_key],{},true,nil,true)
			targetPhoto:addKeyword(keyword)
		end)
	end)
end


--------		check_request_and_add_keywords			---------
local function check_request_and_add_keywords(_table)
	local _t = _table
	if _t.apiKey ~= '' then
		local	response = _t.request_function()
		if response == false then
			return false
		end

		--	add keywords to photo
		addKeywordsToPhoto(_t.targetPhoto,response,_t.tag_key)
	end
end


--[[------		createThumbnail			---------
	Create  thumbnail and post to server
	Add keywords if success
	Return false and show error dialog if error
	@targetPhoto		a photo
------------------------------------------------]]
local function createThumbnail(targetPhoto)

	targetPhoto:requestJpegThumbnail(THUMBNAIL_SIZE,THUMBNAIL_SIZE,
		function(data,err)
			
			if	err then
				createErrorDialog(err)
				is_error = true
				return false
			end
			
			if GOOGLE_API_KEY == '' and IMAGGA_API_KEY == '' then
				createErrorDialog(ERROR_REQUIRE_API_KEY)
			end
			
		
			--------------------	Google		--------------------------
			if check_request_and_add_keywords(
				{
					targetPhoto = targetPhoto,
					apiKey = GOOGLE_API_KEY,
					request_function = function() return (google_request(targetPhoto,data)) end,
					tag_key = "description"
				}
			) == false then
				return false
			end

			--------------------	Imagga		--------------------------
			if check_request_and_add_keywords(
				{
					targetPhoto = targetPhoto,
					apiKey = IMAGGA_API_KEY,
					request_function = function() return (imagga_request(targetPhoto,data)) end,
					tag_key = "tag"
				}
			) == false then
				return false
			end
		end
	)
end


local function	mainFunction()
	
	local activeCat = LrApplication.activeCatalog()					--	active Catalog
	local targetPhotos = activeCat:getTargetPhotos()				--	selected photos

	foreach( targetPhotos,function(key)
	
		createThumbnail(targetPhotos[key])
		
		
		--	break loop if error occure
		if  is_error then
			return false
		end
	end)
end


--	start task
LrTasks.startAsyncTask(function()
	
	mainFunction()
end)
