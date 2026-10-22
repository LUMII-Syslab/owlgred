import { Interpreter } from '../../../../client/lib/interpreter.js'
import { Elements, ElementTypes, CompartmentTypes, Compartments } from '../../../../db/platform/collections.js'
import { Dialog } from '../../../../platform/client/js/interpretator/Dialog.js'

import { Create_OWLGrEd_Element } from './OWLGrEd_Element.js'

import * as class_expression_grammar_completion_parser_OWLGrEd from './class_expression_grammar_completion_parser_OWLGrEd.js'
import * as data_range_grammar_completion_parser_OWLGrEd from './data_range_grammar_completion_parser_OWLGrEd.js'

var symbolTable = {};
var grammarType = "class";
var time;
var schemaNameFromABS = null;
var schemaNames = [];

Interpreter.customMethods({

	expressionAutoCompletion: async function(e, compart) {
		grammarType = "class"
		let ev = e.originalEvent;
		if ((ev.ctrlKey || ev.metaKey) && ev.code === 'Space') {
			const d = new Date();
			time = d.getTime();
			await autoCompletion(e);
		}		
	},
	
	typeExpressionAutoCompletion: async function(e, compart) {
		grammarType = "type"
		let ev = e.originalEvent;
		if ((ev.ctrlKey || ev.metaKey) && ev.code === 'Space') {
			const d = new Date();
			time = d.getTime();
			await autoCompletion(e);
		}	
	},

});

var currentFocus = 0;


const autoCompletionExpression = async function(e) {
	grammarType = "class"
	let ev = e.originalEvent;
	if ((ev.ctrlKey || ev.metaKey) && ev.code === 'Space') {
		const d = new Date();
		time = d.getTime();
		await autoCompletion(e);
	}
}

const autoCompletionTypeExpression = async function(e) {
	grammarType = "type"
	let ev = e.originalEvent;
	if ((ev.ctrlKey || ev.metaKey) && ev.code === 'Space') {
		const d = new Date();
		time = d.getTime();
		await autoCompletion(e);
	}
}

const autoCompletion = async function(e) {

	removeMessage();
	// if ((e.ctrlKey || e.metaKey) && (e.keyCode === 32 || e.keyCode === 0)) {
	// if (!isAutocompletionActive() && e.keyCode !== 27 && e.keyCode !== 9) {
	if (isAutocompletionKey(e) && !isAutocompletionActive()) {
		await delay(1);
		var elem = document.activeElement;

		var text = e.originalEvent.target.value;
		var textBefore = text.substring(0, elem.selectionStart);
		var continuations = await runCompletionNew(textBefore, text, textBefore.length, symbolTable);

		if(typeof continuations == "string" && continuations.startsWith("ERROR")){
			errorMessage(continuations, elem);
			elem.addEventListener("keyup", keyUpHandler);
			elem.addEventListener("click", clickHandler);
			//autocomplete(elem, continuations);
		} else if(typeof continuations == "string" &&  continuations == "leaveOldRessult"){

		}else{
			elem.addEventListener("keyup", keyUpHandler);
			elem.addEventListener("click", clickHandler);
			await autocomplete(elem, continuations);
		}
	}
}

const autoCompletionCleanup = function() {
	// console.log('auto completion cleanup');
	removeMessage();
	closeAllLists();
	symbolTable = null;
	schemaNameFromABS = null;
	schemaNames = [];
}

const delay = ms => new Promise(res => setTimeout(res, ms));

const isAutocompletionActive = function() {
	const aList = document.getElementById('autocomplete-list');
	const active = !!aList;
	// console.log('AC active:', active)
	return active;
}

const AUTOCOMPLETE_EXCLUSIONS = [
	'Escape',
	'Tab',
	'Delete',
	'Backspace',
	'CapsLock',
];

const isAutocompletionKey = function(e) {
	let ev = e.originalEvent;

	if ((ev.ctrlKey || ev.metaKey) && ev.code === 'Space') return true;
	if (ev.ctrlKey || ev.metaKey) return false;
	return ev.location === 0 && !AUTOCOMPLETE_EXCLUSIONS.includes(ev.key);
}

async function requestAndProcessContinuations(textBefore, text, cursorPosition, symbolTable) {
	var continuations = await runCompletionNew(textBefore, text, textBefore.length, symbolTable);

	if (typeof continuations == "string" && continuations.startsWith("ERROR")){
		errorMessage(continuations,  document.activeElement);
		closeAllLists();
	}else{
		await autocomplete(document.activeElement, continuations);
	}
}

var requestAndProcessContinuationsDebounced = _.debounce(requestAndProcessContinuations, 300);

function keyUpHandler(e){
	if (e.keyCode === 8){
		var m = document.getElementById("message");
		if(m !== null) {
			removeMessage();
			const text = e.target.value;
			let textBefore = text.substring(0, e.target.selectionStart);
			requestAndProcessContinuationsDebounced(textBefore, text, textBefore.length, symbolTable);
		}
	}

	if (e.keyCode !== 40 && e.keyCode !== 38 && e.keyCode !== 13 && e.keyCode !== 9 && e.keyCode !== 27){
		if(document.getElementsByClassName("autocomplete-items").length > 0){
			removeMessage();
			const text = e.target.value;
			let textBefore = text.substring(0, e.target.selectionStart);
			requestAndProcessContinuationsDebounced(textBefore, text, textBefore.length, symbolTable);
		}
	}
}

function keyDownHandler(e){

	if (!isAutocompletionActive()) return;
	const aList = document.getElementById("autocomplete-list");
	const listItems = aList.getElementsByTagName("div");




	if (e.keyCode === 40) {//arrow down
		e.preventDefault();
		currentFocus++;
		addActive(listItems);
	} else if (e.keyCode === 38) { //arrow up
		e.preventDefault();
		currentFocus--;
		addActive(listItems);
	} else if (e.keyCode === 13) { //ENTER
		var text = e.target.value;
		var textBefore = text.substring(0, e.target.selectionStart);
		var sug = listItems[currentFocus].querySelector('input[name="prefix"]').value + listItems[currentFocus].querySelector('input[name="suggestion"]').value;
		if(sug.startsWith(textBefore)){
			e.preventDefault();
			e.stopPropagation();
			if (currentFocus === -1) currentFocus = 0;
			if (currentFocus > -1) {
				if (listItems) listItems[currentFocus].click();
			}
		}

	} else if (e.keyCode === 9) { //TAB
		e.preventDefault();
		if (currentFocus === -1) currentFocus = 0;
		if (currentFocus > -1) {
			if (listItems) listItems[currentFocus].click();
		}
	} else if (e.keyCode === 27) { //ESC
		e.preventDefault();
		closeAllLists();
		return false;
	}
}

function clickHandler(e){
	closeAllLists();
	//var elem = document.activeElement;
	//elem.removeEventListener("keyup", keyUpHandler);
}

function autocomplete(inp, continuations) {

	const colorForType = (type) => {
		switch (type) {
			case 1: return '#800000';
			case 2: return '#008000';
			case 3: return '#000080';
			case 4: return '#008080';
			default: return '#404040';
		}
	};

	const descriptionForType = (type) => {
		switch (type) {
			case 1: return 'data property';
			case 2: return 'object property';
			case 3: return 'schema element';
			case 4: return 'language construct';
			default: return 'other';
		}
	};

	removeMessage();
	var cursorPosition = inp.selectionStart;

	var a, b, i, val = inp.value;

    /*close any already open lists of autocompleted values*/
    closeAllLists();

	if (typeof continuations === 'string') { // should not happen
		// continuations = { prefix: '', suggestions: []}
		return;
	}
	if (typeof continuations.suggestions === "undefined" || continuations.suggestions.length === 0) {
		// continuations.suggestions.push({type: 0, name: '-- no suggestions found --'});
		// continuations.suggestions.push({type: 0, name: ''});
		return;
	}

	let ss = continuations.suggestions;
	let nonLanguageConstruct = ss.find(s => s.type < 4);
	if (!nonLanguageConstruct) {
		ss.push({type: 0, name: '', priority: Number.MAX_SAFE_INTEGER});
	}

	ss.sort((a, b) => b.priority - a.priority);

	if (inp.parentElement && inp.parentElement.tagName === "DIV") {

		/*create a DIV element that will contain the items (values):*/
		a = document.createElement("DIV");

		a.style.display = 'block';
		a.style.position = 'auto';
		a.style.width = '100%';
		a.style.maxHeight = '200px';
		a.style.overflow = 'hidden';
		a.style.overflowY = 'auto';
		a.style.listStyle = 'none';
		a.style.padding = '2px';
		a.style.margin = 0;
		a.style.border = '1px solid #bbb';
		a.style.backgroundColor = '#efefef';
		a.style.boxShadow = '0px 0px 6px 1px rgba(128,128,128,0.3)';
		a.style.borderRadius = '4px';

		a.setAttribute("id", "autocomplete-list");
		a.setAttribute("class", "autocomplete-items");

		/*append the DIV element as a child of the autocomplete container:*/
		inp.parentNode.appendChild(a);

		for (let [i, sugg] of ss.entries()) {
			/*create a DIV element for each matching element:*/
			b = document.createElement("DIV");

			b.innerHTML = `<span style='color: #808080'>${continuations.prefix}</span><span style='font-weight: 900; color: ${colorForType(sugg.type)}'>${sugg.name}</span>`;
			b.innerHTML += ` <span style='color: #c0c0c0; float: right'>(${descriptionForType(sugg.type)})</span>`;
			/*insert a input field that will hold the current array item's value:*/
			b.innerHTML += `<input type='hidden' value='${sugg.name}' name='suggestion'>`;
			b.innerHTML += `<input type='hidden' value='${continuations.prefix}' name='prefix'>`;

			/*execute a function when someone clicks on the item value (DIV element):*/
			b.addEventListener("click", async function(e) {
				/*insert the value for the autocomplete text field:*/
				// var inputValue = generateInputValue(inp.value, this.getElementsByTagName("input")[0].value, cursorPosition);
				// inp.value = inputValue;
				await updateInputValue(inp, continuations.prefix, sugg.name);
				/*close the list of autocompleted values,(or any other open lists of autocompleted values:*/
				closeAllLists();
				inp.focus();
			});

			if (i === currentFocus) b.style.backgroundColor = '#f8c26c';
			a.appendChild(b);

		}

		inp.removeEventListener("keydown", keyDownHandler);
		inp.addEventListener("keydown", keyDownHandler);
	}
}

//function to classify an item as selected
function addActive(x) {
	if (!x) return false;
	removeActive(x);
	if (currentFocus >= x.length) currentFocus = 0;
	if (currentFocus < 0) currentFocus = (x.length - 1);
	x[currentFocus].style.backgroundColor = '#f8c26c';
	x[currentFocus].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

//function to remove selected item
function removeActive(x) {
	for(let i = 0; i < x.length; i++) {
		x[i].style.backgroundColor = '#efefef';
	}
}

function closeAllLists(elmnt) {
    /*close all autocomplete lists in the document, except the one passed as an argument:*/
    var x = document.getElementsByClassName("autocomplete-items");

    for(let i = 0; i < x.length; i++) {
      if (elmnt !== x[i] && elmnt !== document.activeElement) {
        x[i].parentNode.removeChild(x[i]);
	  }
	}
	currentFocus = 0;
}

async function updateInputValue(input, prefix, suggestion) {
	let selStart = input.selectionStart;
	let selEnd = input.selectionEnd;
	let tail = input.value.slice(selEnd);
	let newValue = prefix + suggestion + tail;
	let cursorPos = prefix.length + suggestion.length;

	// if(grammarType == "instance") newValue = "="+newValue;

	input.value = newValue;

	input.selectionStart = cursorPos;
	input.selectionEnd = cursorPos;

	input.blur();
	input.focus();

	const act_elem = Session.get("activeElement");
	const act_el = await Elements.findOneAsync({_id: act_elem});
	if(typeof act_el !== 'undefined'){
		const compart_type_id = $(input).closest(".parent-compartment").closest(".compart-type").attr("id");
		// const compart_type_id = $(input).closest(".compart-type").attr("id");
		const compart_type = await CompartmentTypes.findOneAsync({_id: compart_type_id});
		if (!compart_type) {
			console.error("No CompartmentType", compart_type_id);
			return;
		}

		const compart = await Compartments.findOneAsync({compartmentTypeId: compart_type_id, elementId: act_elem});
		if(typeof compart !== "undefined"){
			let elem = await Create_OWLGrEd_Element(act_elem);
      if (elem.isIndirectClassMembership()) {
				Dialog.updateCompartmentValue(compart_type, act_elem, newValue, ".. "+newValue, compart["_id"]);
			} else {
				Dialog.updateCompartmentValue(compart_type, act_elem, newValue, newValue, compart["_id"]);
			};
		}
	}
}

function isURI(text) {
  if(text.indexOf("://") !== -1)
    return 3;
  else
    if(text.indexOf(":") !== -1) return 4;
  return 0;
};

const runCompletionNew = async function (text, fullText, cursorPosition, symbolTable){

		const act_elem = Session.get("activeElement");

		try {

			if(grammarType == "class"){
				let parsed_exp = await class_expression_grammar_completion_parser_OWLGrEd.parse(text, {time:time, text:text, type:grammarType});
			
			} else if(grammarType == "type"){
				let parsed_exp = await data_range_grammar_completion_parser_OWLGrEd.parse(text, {time:time, text:text, type:grammarType});
			
			}
		} catch (com) {
			// console.log(com);
			// console.log(JSON.stringify(com["message"], null, 2));
			// console.log(JSON.parse(com["message"]));
			var cont = JSON.parse(com["message"]);
			// if(time == cont.time){
				let c = getContinuationsNew(text, text.length, cont);
				return c;
			// } else {return "leaveOldRessult"}
		}
	return [];
}

function getCompletionTableNew(continuations_to_report, text) {
	var sortable = [];
	for(let key in continuations_to_report) {
		if(continuations_to_report[key]["name"] !== "" && continuations_to_report[key]["name"] !== " "){
			if(continuations_to_report[key]["spaceBefore"] == true && text.length !== 0 && text.substring(text.length-1) !== " ") sortable.push({"name":" "+continuations_to_report[key]["name"], "priority":continuations_to_report[key]["priority"], "type":continuations_to_report[key]["type"]});
			else sortable.push({"name":continuations_to_report[key]["name"], "priority":continuations_to_report[key]["priority"], "type":continuations_to_report[key]["type"]});
		}// sortable.push(continuations_to_report[key]);
	}

	sortable = sortable.sort(function (a, b) {
		if (a.type < b.type) return -1;
		if (a.type > b.type) return 1;

		if (a.priority < b.priority) return 1;
		if (a.priority > b.priority) return -1;

	});

	return sortable
}

//text - input string
//length - input string length
function getContinuationsNew(text, length, continuations) {

	var allSuggestions = []
	var farthest_pos = -1 //farthest position in continuation table
	var farthest_pos_prev = -1 // previous farthest position (is used only some nonterminal symbol is started)
	var continuations_to_report;

	var prefix = text;

	//find farthest position in continuation table
	//find  previous farthest position



	for(let pos in continuations) {
		if (farthest_pos !== -1) {
			farthest_pos_prev = farthest_pos
		}
		if (parseInt(pos) > farthest_pos) {
			farthest_pos = parseInt(pos)
			continuations_to_report = continuations[pos]
		}
	}

	if (farthest_pos_prev !== -1) {
		for (let i = farthest_pos; i >=0; i--) {
			if (continuations[i] !== null) {
				var varrible = text.substring(i, farthest_pos);

				var startedContinuations = [];
				var wholeWordMatch = false;

				for(let pos in continuations[i]) {
					if(varrible.toLowerCase() == pos.toLowerCase()) wholeWordMatch = true;
				}

				for(let pos in continuations[i]) {
					//if contuniation contains sub string
					if (isNaN(varrible.substring(0, 1)) !== false && wholeWordMatch!= true && pos.toLowerCase().includes(varrible.toLowerCase()) && varrible.toLowerCase() !== pos.toLowerCase() && varrible !== "") {
						prefix = text.substring(0, i);
						continuations_to_report[pos] = continuations[i][pos];
						startedContinuations["'"+pos+"'"] = continuations[i][pos];
					}
					else {
						//if starts with
						if (pos.substring(0, varrible.length).toLowerCase() == varrible.toLowerCase() && varrible.toLowerCase() !== pos.toLowerCase() && varrible !== "") {
							var suggestions = pos.substring(varrible.length);

							continuations_to_report[pos] = {"name":suggestions, "priority":100, "type":continuations[i][pos]["type"], "spaceBefore":false}
							startedContinuations[pos] = {"name":suggestions, "priority":100, "type":continuations[i][pos]["type"], "spaceBefore":false}

						}
					}
				}

				if(Object.keys(startedContinuations).length > 0 && wholeWordMatch !== true) continuations_to_report = startedContinuations;
			}
		}
	}

	var TermMessages=[];

	if (length>=farthest_pos) {
		//nemam mainigo no kludas vietas lidz beigam
		var er = text.substring(farthest_pos, length)
		var er_lenght = er.length

		//parbaudam, vai ir saderibas iespejamo turpinajumu tabulaa
		for(let pos in continuations_to_report) {
			if (pos.substring(0, er_lenght).toLowerCase() == er.toLowerCase()) {
				TermMessages["'"+pos+"'"]=continuations_to_report[pos];
				if(length>farthest_pos) prefix = text.substring(0, farthest_pos);
			}
		}

		if (Object.keys(TermMessages).length > 0) {
			TermMessages = getCompletionTableNew(TermMessages, text)
			return {prefix:prefix, suggestions:TermMessages}
		//ja nebija sakritibu iespejamo turpinajumu tabulaa, tad ir kluda
		} else {
			let uniqueMessages = getCompletionTableNew(continuations_to_report, text)

			let messages = "ERROR: in a position " + farthest_pos + ", possible continuations are:";

			for(let pos in uniqueMessages) {
				if(uniqueMessages.length-1 > pos)messages = messages+ "\n" + uniqueMessages[pos]["name"] + ",";
				else messages = messages+ "\n" + uniqueMessages[pos]["name"];
			}
			return messages
		}
	}
	let uniqueMessages = getCompletionTableNew(continuations_to_report, text);
	return {prefix:prefix, suggestions:uniqueMessages}
}

function errorMessage(message, elem) {
    if (!elem || !elem.parentElement) return;

    removeMessage();

    const m = document.createElement("div");

    m.style.color = '#691715';
    m.style.background = '#feded9';
    m.style.border = '1px solid #fc8675';
    m.style.display = 'block';
    m.style.whiteSpace = 'pre-line';

    m.setAttribute("id", "message");
    m.setAttribute("class", "message");

    const label = document.createElement("label");
    label.textContent = message;
    m.appendChild(label);

    elem.parentElement.insertBefore(m, elem);
}

function removeMessage(){
	var m = document.getElementById("message");
	if(m !== null) m.parentNode.removeChild(m);
}

function findClassInAbstractQueryTable(elemId, abstractQueryTable){
	var clazz;
	if(abstractQueryTable["identification"]["_id"] == elemId) clazz = abstractQueryTable;
	else{
		for(let child in abstractQueryTable["children"]){
			if(typeof abstractQueryTable["children"][child] !== "function") clazz = findClassInAbstractQueryTable(elemId, abstractQueryTable["children"][child])
		}
	}
	return clazz;
}

export {
  autoCompletionExpression,
  autoCompletionTypeExpression,
  autoCompletionCleanup,
}
