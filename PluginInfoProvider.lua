--[[

===============================================================

					Plugin Info Provider

	Create input dialog in Plug-in Manager

	input:
		- Google API KEY 
		- Imagga API KEY
					
===============================================================]]
	


local LrHttp = import "LrHttp"
local LrView = import "LrView"
local LrColor = import "LrColor"
local LrBinding = import "LrBinding"
local LrFunctionContext = import "LrFunctionContext"
local prefs = import "LrPrefs".prefsForPlugin()

--	Shorthand
local bind = LrView.bind




--[[------		checkprefs			---------
	Set prefs[@key] if not  exist
--------------------------------------------]]
local function checkPrefs(key)
	if prefs[key] == nil then
		prefs[key] = ''
	end
end

--[[------		savePrefs			---------
	Set prefs[@key] as last @value
	return @value to binding key
--------------------------------------------]]
local function savePrefs(key)

	return (
		function(value,fromTable)
			prefs[key] = value 
			return value 
		end
	)
end


--	check all prefs
checkPrefs("google_key")
checkPrefs("imagga_key")

local function sectionsForTopOfDialog( f, _ )

	--	Shorthand for design layout
	local _top_padding = f:spacer{height = 5}
	local _bottom_padding = f:spacer{height = 5}
	local _color_gray = LrColor(0.3)
	local _description_width = 12
	
	
	return LrFunctionContext.callWithContext( 'PluginInfoProvider', function(context)
		--	Create Property to binding
		local properties = LrBinding.makePropertyTable( context )
		properties.google_key = prefs.google_key  					-- For Google API Key
		properties.imagga_key = prefs.imagga_key 					-- For imagga API Key
		return {
			-- Section for the top of the dialog.
			{
				------------	Google		------------
				title = LOC "$$$/autoTag/PluginManager=Google Cloud Vision API",
				
				_top_padding,
				f:row {
					bind_to_object = properties,
					f:static_text {
						--	input:Google API KEY
						title = LOC "$$$/autoTag/Title1=API Key",
						width_in_digits = _description_width,
					},
					
					f:edit_field{
						value = bind({key="google_key",transform=savePrefs("google_key"),}),
						fill_horizontal = 1,
					},
				
				
				},
				f:row{
					f:static_text {
						width_in_digits = _description_width,
					},
					f:static_text{
						title="Copy key from https://console.cloud.google.com/apis/credentials or leave blank to disable ",
						fill_horizontal = 1,
						text_color = _color_gray,
					}
				},
								f:row{
					f:picture{
						value = _PLUGIN:resourceId( "google.jpg" ),
						place_horizontal = 1,
						alignment = "right",
					}
					
				},
				f:row{
				
					f:static_text{
						title="Powered by Google Cloud Platform",
						fill_horizontal = 1,
						text_color = _color_gray,
						alignment = "right",
						mouse_down = function() LrHttp.openUrlInBrowser("https://cloud.google.com/vision/") end
					}
					
				},
				_bottom_padding,
			},
			
			{
				------------	Imagga		------------
				title = LOC "$$$/autoTag/PluginManager=Imagga",
				
				_top_padding,
				f:row {
					bind_to_object = properties,
					f:static_text {
						--	input:Imagga API KEY
						title = LOC "$$$/autoTag/Title1=API Key",
						width_in_digits = _description_width,
					},
					
					f:edit_field{
						value = bind({key="imagga_key",transform=savePrefs("imagga_key"),}),
						fill_horizontal = 1,
					},
				
				
				},

				f:row{
				
					f:static_text {
						width_in_digits = _description_width,
					},
					f:static_text{
						title="Leave blank to disable",
						fill_horizontal = 1,
						text_color = _color_gray,
					}
					
				},
				f:row{
					f:picture{
						value = _PLUGIN:resourceId( "imagga.jpg" ),
						place_horizontal = 1,
						alignment = "right",
					}
					
				},
				f:row{
				
					f:static_text{
						title="Powered by Imagga",
						fill_horizontal = 1,
						text_color = _color_gray,
						alignment = "right",
						mouse_down = function() LrHttp.openUrlInBrowser("https://imagga.com/") end
					}
					
				},
				
				_bottom_padding,
			},
	
		}
	end)
		
end

return{

	sectionsForTopOfDialog = sectionsForTopOfDialog,

}
