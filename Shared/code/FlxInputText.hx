package ;

import flash.display.BitmapData;
import flash.errors.Error;
import flash.events.KeyboardEvent;
import flash.geom.Rectangle;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxPoint;
import flixel.util.FlxRect;
import flixel.util.FlxTimer;
import flixel.FlxG;
	
/**
 * FlxInputText v1.11, ported to Haxe
 * @author larsiusprime, (Lars Doucet)
 * @link http://github.com/haxeflixel/flixel-ui
 * 
 * FlxInputText v1.10, Input text field extension for Flixel
 * @author Gama11, Mr_Walrus, nitram_cero (Martín Sebastián Wain)
 * @link http://forums.flixel.org/index.php/topic,272.0.html
 * 
 * Copyright (c) 2009 Martín Sebastián Wain
 * License: Creative Commons Attribution 3.0 United States
 * @link http://creativecommons.org/licenses/by/3.0/us/
 */
class FlxInputText extends FlxText 
{		
	public static inline var NO_FILTER:Int			= 0;
	public static inline var ONLY_ALPHA:Int			= 1;
	public static inline var ONLY_NUMERIC:Int		= 2;
	public static inline var ONLY_ALPHANUMERIC:Int	= 3;
	public static inline var CUSTOM_FILTER:Int		= 4;
	
	public static inline var ALL_CASES:Int			= 0;
	public static inline var UPPER_CASE:Int			= 1;
	public static inline var LOWER_CASE:Int			= 2;
	
	public static inline var BACKSPACE_ACTION:String = "backspace";		//press backspace
	public static inline var DELETE_ACTION:String = "delete";			//press delete
	public static inline var ENTER_ACTION:String = "enter";				//press enter
	public static inline var INPUT_ACTION:String = "input";				//manually edit
	
	//workaround to deal with non-availability of getCharIndexAtPoint or getCharBoundaries on cpp/neko targets
	#if sys
		private var charBoundaries:Array<FlxRect> = null;
	#end
	
	/**
	 * Defines what text to filter. It can be NO_FILTER, ONLY_ALPHA, ONLY_NUMERIC, ONLY_ALPHA_NUMERIC or CUSTOM_FILTER
	 * (Remember to append "FlxInputText." as a prefix to those constants)
	 */
	private var _filterMode:Int = NO_FILTER;
	
	/**
	 * This regular expression will filter out (remove) everything that matches. 
	 * This is activated by setting filterMode = FlxInputText.CUSTOM_FILTER.
	 */
	//public var customFilterPattern:EReg = ~/[]*/g;
	public var customFilterPattern:EReg;
	
	/**
	 * A function called whenever the value changes from user input, or enter is pressed
	 */
	public var callback:String->String->Void;
	
	public var params(default, set):Array<Dynamic> = null;
	
	/**
	 * Whether this text box has focus on the screen.
	 */
	private var _hasFocus:Bool;
	
	/**
	 * The position of the selection cursor. An index of 0 means the carat is before the character at index 0.
	 */
	public var _caretIndex:Int = -1;
	
	/**
	 * If this is set to true, text typed is forced to be uppercase.
	 */
	private var _forceCase:Int = ALL_CASES;
	
	/**
	 * The max amount of characters the textfield can contain.
	 */
	private var _maxLength:Int = 0;
	
	/**
	 * The amount of lines allowed in the textfield.
	 */
	private var _lines:Int = 1;
	
	/**
	 * The color of the background of the textbox.
	 */
	public var backgroundColor:Int;
	
	/**
	 * Whether or not the textbox has a background
	 */
	public var background:Bool = false;
	
	/**
	 * A FlxSPrite representing the background sprite
	 */
	private var backgroundSprite:FlxSprite;
	 
	/**
	 * A timer for the flashing caret effect.
	 */
	private var caretTimer:FlxTimer;
	
	/**
	 * A FlxSprite representing the flashing caret when editing text.
	 */
	private var caret:FlxSprite;
	
	/**
	 * The caret's color. Has the same color as the text by default.
	 */
	public var caretColor:Int;
	
	/**
	 * A FlxSprite representing the fieldBorders.
	 */
	private var fieldBorderSprite:FlxSprite;
	
	/**
	 * The thickness of the borders. 0 to disable.
	 */
	private var _fieldBorderThickness:Int = 1;
	
	/**
	 * The color of the borders.
	 */
	private var _fieldBorderColor:Int = 0xFF000000;
	
	/**
	 * Creates a new FlxText object at the specified position.
	 * @param	X				The X position of the text.
	 * @param	Y				The Y position of the text.
	 * @param	Width			The width of the text object (height is determined automatically).
	 * @param	Text			The actual text you would like to display initially.
	 * @param   size			Initial size of the font	 
	 * @param	EmbeddedFont	Whether this text field uses embedded fonts or not
	 */
	public function new(X:Float, Y:Float, Width:Int=200, Text:String=null, size:Int = 8, TextColor:Int = 0xFF000000, BackgroundColor:Int = 0xFFFFFFFF, EmbeddedFont:Bool=true)
	{
		customFilterPattern = null;// ~/[]*/g;
		
		super(X, Y, Width, Text, size, EmbeddedFont);
		
		backgroundColor = BackgroundColor;
		if (BackgroundColor != 0) background = true;
		
		color = TextColor;
		caretColor = TextColor;
			
		caret = new FlxSprite();
		caret.makeGraphic(1, Std.int(size + 2), 0xFFFFFFFF);
		caret.color = caretColor;
		caretIndex = 0;
		
		hasFocus = false;
		fieldBorderSprite = new FlxSprite(X, Y);
		backgroundSprite = new FlxSprite(X, Y);
		
		lines = 1;
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, handleKeyDown);
		
		calcFrame();
	}
	
	public function set_params(p:Array<Dynamic>):Array<Dynamic> {
		params = p;
		if (params == null) { params = [];}
		var namedValue:NamedString = { name:"value", value:text};
		params.push(namedValue);
		return p;
	}
	
	/**
	 * Draw the caret in addition to the text.
	 */
	override public function draw():Void 
	{
		drawSprite(fieldBorderSprite);
		drawSprite(backgroundSprite);
		
		super.draw();
		
		// In case caretColor was changed
		if (caretColor != caret.color || caret.height != size + 2) 
			caret.color = caretColor;
		
		drawSprite(caret);
	}
	
	/**
	 * Helper function that makes sure sprites are drawn up even though they haven't been added.
	 * @param	Sprite		The Sprite to be drawn.
	 */
	private function drawSprite(Sprite:FlxSprite):Void
	{
		if (Sprite != null && Sprite.visible) {
			Sprite.scrollFactor = scrollFactor;
			Sprite.cameras = cameras;
			Sprite.draw();
		}
	}
	
	/**
	 * Check for mouse input every tick.
	 */
	override public function update():Void 
	{
		super.update();
		
		#if (!FLX_NO_MOUSE  && !FLX_NO_TOUCH)
		// Set focus and caretIndex as a response to mouse press
		if (FlxG.mouse.justPressed) {
			if (overlapsPoint(new FlxPoint(FlxG.mouse.x, FlxG.mouse.y))) {
				caretIndex = getCaretIndexFromPoint(new FlxPoint(FlxG.mouse.x, FlxG.mouse.y));
				hasFocus = true;
			}
			else {
				hasFocus = false;
			}
		}
		#end
	}
	
	/**
	 * Handles keypresses generated on the stage.
	 * @param	e		The triggering keyboard event.
	 */
	private function handleKeyDown(e:KeyboardEvent):Void 
	{
		var key:Int = e.keyCode;
		
		if (hasFocus) {
			// Do nothing for Shift, Ctrl and flixel console hotkey
			if (key == 16 || key == 17 || key == 220) 
			{
				return;
			}
			// Left arrow
			else if (key == 37) 
			{ 
				if (caretIndex > 0) caretIndex --;
			}
			// Right arrow
			else if (key == 39) 
			{ 
				if (caretIndex < text.length) caretIndex ++;
			}
			// Backspace
			else if (key == 8) 
			{
				if (caretIndex > 0) {
					var s:String;
					text = text.substring(0, caretIndex - 1) + text.substring(caretIndex);
					caretIndex --;
					onChange(BACKSPACE_ACTION);
				}
			}
			// Delete
			else if (key == 46)
			{
				if (text.length > 0 && caretIndex < text.length) {
					text = text.substring(0, caretIndex) + text.substring(caretIndex + 1);
					onChange(DELETE_ACTION);
				}
			}
			// Enter
			else if (key == 13) 
			{
				onChange(ENTER_ACTION);
			}
			// Actually add some text
			else 
			{
				var newText:String = filter(String.fromCharCode(e.charCode));
				
				if (newText.length > 0 && (maxLength == 0 || (text.length + newText.length) < maxLength)) {
					text = insertSubstring(text, newText, caretIndex);
					caretIndex++;
					onChange(INPUT_ACTION);
				}
			}
		}
	}
	
	private function onChange(action:String):Void {
		if (callback != null) {
			callback(text, action);
		}
	}
	
	/**
	 * Inserts a substring into a string at a specific index
	 * @param	Insert			The string to have something inserted into
	 * @param	Insert			The string to insert
	 * @param	Index			The index to insert at
	 * @return					Returns the joined string for chaining.
	 */
	private function insertSubstring(Original:String, Insert:String, Index:Int):String 
	{
		if (Index != Original.length) {
			
			Original = Original.substring(0, Index) + (Insert) + (Original.substring(Index));
			//Original = Original.slice(0, Index).concat(Insert).concat(Original.slice(Index));
		}
		else {
			Original = Original + (Insert);
		}
		return Original;
	}
	
	/**
	 * Gets the index of a character in this box at a point
	 * @param	Landing			The point to check for.
	 * @return					The index of the character hit by the point. 
	 * 							Returns -1 if the point is not found.
	 */
	public function getCaretIndexFromPoint(Landing:FlxPoint):Int
	{
	#if !FLX_NO_MOUSE
		var hit:FlxPoint = new FlxPoint(FlxG.mouse.x - x, FlxG.mouse.y - y);
		var caretRightOfText:Bool = false;
		#if !js
			if (hit.y < 2) hit.y = 2;
			else if (hit.y > _textField.textHeight + 2) hit.y = _textField.textHeight + 2;
			if (hit.x < 2) hit.x = 2;
			else if (hit.x > _textField.getLineMetrics(0).width) {
				hit.x = _textField.getLineMetrics(0).width;
				caretRightOfText = true;
			}
			else if (hit.x > _textField.getLineMetrics(_textField.numLines-1).width && hit.y > _textField.textHeight - _textField.getLineMetrics(_textField.numLines - 1).ascent) {
				hit.x = _textField.getLineMetrics(_textField.numLines - 1).width;
				caretRightOfText = true;
			}
		#end
		var index:Int = 0;
		
		if (caretRightOfText) {
			#if flash
				index = _textField.getCharIndexAtPoint(hit.x, hit.y) + 1;
			#elseif sys
				index = getCharIndexAtPoint(hit.x, hit.y) + 1;
			#end
		}
		else {
			#if flash
				index = _textField.getCharIndexAtPoint(hit.x, hit.y);
			#elseif sys
				index = getCharIndexAtPoint(hit.x, hit.y);
			#end
		}
		
		return index;
	#else
		return 0;
	#end
	}
	
	#if sys
		//WORKAROUND since this function isn't available for openfl-native TextFields, we just hack it ourselves
		private function getCharIndexAtPoint(X:Float, Y:Float):Int {
			var i:Int = 0;
			if (charBoundaries != null) {
				var r:FlxRect = null;
				for (r in charBoundaries) {
					if (X >= r.left && X <= r.right && Y >= r.top && Y <= r.bottom) {
						return i;
					}
					i++;
				}
			}
			
			return -1;
		}
		
		private function getCharBoundaries(charIndex:Int):Rectangle {
			if (charBoundaries != null && charIndex > 0 && charIndex < charBoundaries.length) {
				var r:Rectangle = new Rectangle();
				return charBoundaries[charIndex].copyToFlash(r);
			}
			return null;
		}
	#end
	
	public override function set_x(X:Float):Float {
		if (fieldBorderSprite != null && fieldBorderThickness > 0) {
			fieldBorderSprite.x = X - fieldBorderThickness;
		}
		if (backgroundSprite != null && background) {
			backgroundSprite.x = X;
		}		
		return super.set_x(X);
	}
	
	public override function set_y(Y:Float):Float {
		if (fieldBorderSprite != null && fieldBorderThickness > 0) {
			fieldBorderSprite.y = Y - fieldBorderThickness;
		}
		if (backgroundSprite != null && background) {
			backgroundSprite.y = Y;
		}
		return super.set_y(Y);
	}
	
	/**
	 * Draws the frame of animation for the input text.
	 * 
	 * @param	RunOnCpp	Whether the frame should also be recalculated if we're on a non-flash target
	 */
	private override function calcFrame(RunOnCpp:Bool = false):Void
	{
		super.calcFrame(RunOnCpp);
		
		if(fieldBorderSprite != null){
			if (fieldBorderThickness > 0) {
				fieldBorderSprite.makeGraphic(Std.int(width + fieldBorderThickness * 2), Std.int(height + fieldBorderThickness * 2), fieldBorderColor);
				fieldBorderSprite.x = x - fieldBorderThickness;
				fieldBorderSprite.y = y - fieldBorderThickness;
			}else if (fieldBorderThickness == 0){
				fieldBorderSprite.visible = false;
			}
		}
		
		if (backgroundSprite != null) 
		{
			if(background){
				backgroundSprite.makeGraphic(Std.int(width), Std.int(height), backgroundColor);
				backgroundSprite.x = x;
				backgroundSprite.y = y;
			}else {
				backgroundSprite.visible = false;
			}
		}
	}
	
	/**
	 * Turns the caret on/off for the caret flashing animation.
	 */
	private function toggleCaret(timer:FlxTimer):Void
	{
		caretTimer.loops ++; // Run the timer forever
		caret.visible = !caret.visible;
	}
	
	/**
	 * Clean up after ourselves
	 */
	override public function destroy():Void 
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, handleKeyDown);
		if (backgroundSprite != null) {
			backgroundSprite.destroy();
			backgroundSprite = null;
		}
		if (fieldBorderSprite != null) {
			fieldBorderSprite.destroy();
			fieldBorderSprite = null;
		}
		#if sys
			if (charBoundaries != null) {
				while (charBoundaries.length > 0) {
					charBoundaries.pop();
				}
				charBoundaries = null;
			}
		#end
		super.destroy();
		callback = null;
	}
	
	/**
	 * Checks an input string against the current 
	 * filter and returns a filtered string
	 * @param	text	Unfiltered text
	 * @return			Text filtered by the the filter mode of the box
	 */
	private function filter(text:String):String
	{
		if (forceCase == UPPER_CASE)
			text = text.toUpperCase();
		else if (forceCase == LOWER_CASE)
			text = text.toLowerCase();
			
		if (filterMode != NO_FILTER) {
			var pattern:EReg;
			switch(filterMode) {
				case ONLY_ALPHA:		pattern = ~/[^a-zA-Z]*/g;		
				case ONLY_NUMERIC:		pattern = ~/[^0-9]*/g;			
				case ONLY_ALPHANUMERIC:	pattern = ~/[^a-zA-Z0-9]*/g;	
				case CUSTOM_FILTER:		pattern = customFilterPattern;	
				default:
					throw new Error("FlxInputText: Unknown filterMode ("+filterMode+")");
			}
			pattern.replace(text, "");
			//text = text.replace(pattern, "");
		}
		return text;
	}
		
	public var hasFocus(get, set):Bool;
	
	/**
	 * Whether or not the text box is the active object on the screen.
	 */
	public function get_hasFocus():Bool
	{
		return _hasFocus;
	}
	
	/**
	 * @private
	 */
	public function set_hasFocus(newFocus:Bool):Bool
	{
		if (newFocus) 
		{
			if (_hasFocus != newFocus) {
				//caretTimer = FlxTimer.start(0.5, toggleCaret, 4);
				caretTimer = new FlxTimer(0.5, toggleCaret, 4);
				caret.visible = true;
				caretIndex = text.length;
			}
			
		}
		else 
		{
			// Graphics
			caret.visible = false;		
			if(caretTimer != null){
				//caretTimer.abort();
				caretTimer.cancel();
			}
		}
		if (newFocus != _hasFocus) calcFrame();
		_hasFocus = newFocus;
		return _hasFocus;
	}
	
	public var caretIndex(get, set):Int;
	
	/**
	 * The position of the selection cursor. An index of 0 means the carat is before the character at index 0.
	 */
	public function get_caretIndex():Int
	{
		return _caretIndex;
	}
	
	/**
	 * @private
	 */
	public function set_caretIndex(newCaretIndex:Int):Int
	{
		
		_caretIndex = newCaretIndex;
		
		// If caret is too far to the right something is wrong
		if (_caretIndex > text.length + 1) _caretIndex = -1; 
		
		// Caret is OK, proceed to position
		if (_caretIndex != -1) 
		{
			var boundaries:Rectangle;
			
			// Caret is not to the right of text
			if (_caretIndex < text.length) { 
				#if flash
					boundaries = _textField.getCharBoundaries(_caretIndex);
				#elseif sys
					boundaries = getCharBoundaries(_caretIndex);
				#end
				if (boundaries != null) {
					caret.x = boundaries.left + x;
					caret.y = boundaries.top + y;
				}
			}
			// Caret is to the right of text
			else { 
				#if flash
					boundaries = _textField.getCharBoundaries(_caretIndex - 1);
				#elseif sys
					boundaries = getCharBoundaries(_caretIndex - 1);
				#end
				if (boundaries != null) {
					caret.x = boundaries.right + x;
					caret.y = boundaries.top + y;
				}
				// Text box is empty
				else if (text.length == 0) { 
					// 2 px gutters
					caret.x = x + 2; 
					caret.y = y + 2; 
				}
			}
		}
		
		// Make sure the caret doesn't leave the textfield on single-line input texts
		if (lines == 1 && caret.x + caret.width > x + width) {
			caret.x = x + width - 2;
		}
		
		return _caretIndex;
	}
	
	public var forceCase(get, set):Int;
	
	/**
	 * Enforce upper-case or lower-case
	 * @param	Case		The Case that's being enforced. Either ALL_CASES, UPPER_CASE or LOWER_CASE.
	 */
	public function get_forceCase():Int
	{ 
		return _forceCase;
	}
	
	public function set_forceCase(Case:Int):Int
	{ 
		_forceCase = Case;
		text = filter(text);
		return _forceCase;
	}
	
	
	//public var size(null, set):Float;
	
	override private function set_size(Size:Float):Float
	{
		super.size = Size;		
		caret.makeGraphic(1, Std.int(size + 2), 0xFFFFFFFF);
		return Size;
	}
	
	public var maxLength(get, set):Int;
	
	/**
	 * Set the maximum length for the field (e.g. "3" 
	 * for Arcade type hi-score initials)
	 * @param	Length		The maximum length. 0 means unlimited.
	 */
	public function get_maxLength():Int
	{
		return _maxLength;
	}
	
	public function set_maxLength(Length:Int):Int
	{
		_maxLength = Length;
		if (text.length > _maxLength){
			text = text.substring(0, _maxLength);
		}
		return _maxLength;
	}
	
	public var lines(get, set):Int;
	
	/**
	 * Change the amount of lines that are allowed.
	 * @param	Lines		How many lines are allowed
	 */
	
	public function get_lines():Int
	{
		return _lines;
	}
	
	public function set_lines(Lines:Int):Int
	{
		if (Lines == 0) return 0;
		
		if (Lines > 1) {
			_textField.wordWrap = true;
			_textField.multiline = true;
		}
		else {
			_textField.wordWrap = false;
			_textField.multiline = false;
		}
		
		_lines = Lines;
		calcFrame();
		return _lines;
	}
	
	public var passwordMode(get, set):Bool;
	
	/**
	 * Whether or not the textfield is a password textfield
	 * @param	enable		Whether to en- or disable password mode
	 */
	public function get_passwordMode():Bool
	{
		return _textField.displayAsPassword;
	}
	
	public function set_passwordMode(enable:Bool):Bool
	{
		_textField.displayAsPassword = enable;
		calcFrame();
		return enable;
	}

	public var filterMode(get, set):Int;
	
	/**
	 * Defines what text to filter. It can be NO_FILTER, ONLY_ALPHA, ONLY_NUMERIC, ONLY_ALPHA_NUMERIC or CUSTOM_FILTER
	 * (Remember to append "FlxInputText." as a prefix to those constants)
	 * @param	newFilter		The filtering mode
	 */
	public function get_filterMode():Int
	{
		return _filterMode;
	}
	
	public function set_filterMode(newFilter:Int):Int
	{
		_filterMode = newFilter;
		text = filter(text);
		return _filterMode;
	}
	
	public var fieldBorderColor(get, set):Int;
	
	/**
	 * The color of the fieldBorders
	 * @param	newColor		The new color 
	 */
	public function set_fieldBorderColor(newColor:Int):Int
	{
		_fieldBorderColor = newColor;
		calcFrame();
		return _fieldBorderColor;
	}
	
	public function get_fieldBorderColor():Int
	{
		return _fieldBorderColor;
	}
		
	public var fieldBorderThickness(get, set):Int;
	
	/**
	 * The thickness of the fieldBorders
	 * @param	newThickness		The new thickness 
	 */
	public function set_fieldBorderThickness(newThickness:Int):Int
	{
		_fieldBorderThickness = newThickness;
		calcFrame();
		return _fieldBorderThickness;
	}
	
	public function get_fieldBorderThickness():Int
	{
		return _fieldBorderThickness;
	}
	
	#if sys												//work-around for native targets
		private override function set_text(Text:String):String
		{
			var return_text:String = super.set_text(Text);
			var numChars:Int = Text.length;
			prepareCharBoundaries(numChars);
			_textField.text = "";
			var textH:Float = 0;
			var textW:Float = 0;
			var lastW:Float = 0;
			for (i in 0...numChars) {
				_textField.appendText(Text.substr(i, 1));	//add a character
				textW = _textField.textWidth;				//count up total text width
				if (i == 0) {
					textH = _textField.textHeight;			//count height after first char
				}
				charBoundaries[i].x = lastW;				//place x at end of last character
				charBoundaries[i].y = 0;					//place y at zero
				charBoundaries[i].width = (textW - lastW);	//place width at (width so far) minus (last char's end point)
				charBoundaries[i].height = textH;
				lastW = textW;
			}
			_textField.text = Text;
			return return_text;
		}
	#end
	
	#if sys
		private function prepareCharBoundaries(numChars:Int):Void {
			if (charBoundaries == null) {
				charBoundaries = [];
			}
			
			if (charBoundaries.length > numChars) {
				var diff:Int = charBoundaries.length - numChars;
				for (i in 0...diff) {
					charBoundaries.pop();
				}
			}
			
			for (i in 0...numChars) {
				if (charBoundaries.length - 1 < i) {
					charBoundaries.push(new FlxRect(0, 0, 0, 0));
				}
			}
		}
	#end
}

typedef NamedString = {
	name:String,
	value:String
}