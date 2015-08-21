# In: message files from an SMG1 disc
# Out: JSON data (as JS file) and CSV data about those messages and the
# time it takes to scroll through them


import argparse
import binascii
import csv
import json
import math
import numpy as np
import os
import re
import struct



def make_lookup():
    lookup = dict()
            
    lookup['colors'] = dict()
    reader = csv.reader(open('color-codes.txt', 'r'), delimiter=',')
    for row in reader:
        code = int(row[0])
        name = row[1]
        lookup['colors'][code] = name
    
    lookup['icons'] = dict()
    reader = csv.reader(open('icon-codes.txt', 'r'), delimiter=',')
    for row in reader:
        code = int(row[0])
        name = row[1]
        lookup['icons'][code] = name
    
    lookup['forced_slow'] = []
    reader = csv.reader(open('forced-slow-messages.txt', 'r'), delimiter=',')
    for row in reader:
        message_id = row[0]
        lookup['forced_slow'].append(message_id)
    
    lookup['numbers_names'] = dict()
    j = json.load(open('number-name-specifics.json', 'r'))
    for message_id, d in j.items():
        lookup['numbers_names'][message_id] = d
    
    lookup['animation_times'] = dict()
    line_regex = re.compile('([A-Za-z0-9_]+) = ([0-9]+)')
    with open('animation-times.txt', 'r') as lines:
        for line in lines:
            line = line.strip()
            if line == '':
                # Blank line
                continue
            elif line.startswith('#'):
                # Comment line
                continue
            # Should be of the form: messageId = 123
            m = line_regex.match(line)
            if m is None:
                raise ValueError(
                    "animation-times line {} is not the expected"
                    " format.".format(line)
                )
            message_id = m.group(1) 
            num_of_frames = int(m.group(2))
            lookup['animation_times'][message_id] = num_of_frames
            
    # This will be filled in during message processing
    lookup['msg_in_msg'] = dict()
    
    return lookup
    
def add_to_box(box, key, value):
    if key == 'chars':
        def add_func(box_case, value): box_case['chars'] += value
    elif key == 'text':
        def add_func(box_case, value): box_case['text'] += value
    elif key == 'pause_length':
        def add_func(box_case, value): box_case['pause_length'] += value
    else:
        raise ValueError("Invalid key for add_to_box: "+key)
    
    if key not in box:
        # box does not have the regular box dict items; this
        # top level dict must be tracking multiple cases instead.
        if type(value) == dict:
            # box has cases, value has cases.
            # Hopefully their cases match up.
            for k,v in value.items():
                if k not in box:
                    raise ValueError(
                        "A message has multiple dimensions of cases,"
                        " and we don't know how to handle that yet."
                    )
                add_func(box[k], v)
        else:
            # box has cases, value does not. Add the value to each of
            # box's cases.
            for k in box.keys():
                add_func(box[k], value)
    else:
        if type(value) == dict:
            # box doesn't have cases, value does. Must change the box
            # structure to have cases now.
            
            # Make a copy of the old box using the dict constructor.
            old_box = dict(box)
            # Empty the box dict.
            box.clear()
            # Fill up the box dict with the new structure.
            for k,v in value.items():
                box[k] = dict(old_box)
                add_func(box[k], v)
        else:
            # A simple message so far: the value in this
            # message is still not dependent on any cases.
            add_func(box, value)
    
def handle_escape_sequence(escape_bytes, boxes, lookup, lang_code, message_id,
    display_colors=False, display_furigana=False):

    if escape_bytes[:4] == b'\x01\x00\x00\x00':
        # Text pause - length is either 10, 15, 30, or 60
        pause_length = escape_bytes[4]
        text = '<Text pause, ' + str(pause_length) + 'L>'
        
        add_to_box(boxes[-1], 'pause_length', pause_length)
    elif escape_bytes[:3] == b'\x01\x00\x01':
        # Message box break.
        text = ''
        boxes.append(dict(chars=0, text="", pause_length=0))
    elif escape_bytes[:3] == b'\x01\x00\x02':
        text = '<Lower-baseline text>'
    elif escape_bytes[:3] == b'\x01\x00\x03':
        text = '<Center align>'
    elif escape_bytes[:5] == b'\x02\x00\x00\x00\x53':
        text = '<Play voice audio>'
    elif escape_bytes[:2] == b'\x03\x00':
        # Icon
        icon_byte = escape_bytes[2]
        icon_type = lookup['icons'][icon_byte]
        text = '<' + icon_type + ' icon>'
        # Any icon counts as one character.
        add_to_box(boxes[-1], 'chars', 1)
    elif escape_bytes[:3] == b'\x04\x00\x00':
        text = '<Small text>'
    elif escape_bytes[:3] == b'\x04\x00\x02':
        text = '<Large text>'
    elif escape_bytes == b'\x05\x00\x00\x00\x00':
        text = '<Player name>'
        lookup['msg_in_msg'][message_id] = dict(
            _placeholder=text,
            mario="System_PlayerName000",
            luigi="System_PlayerName100",
        )
        
        # TODO: Remove?
        # if lang_code == 'us':
        #     # Mario
        #     add_box_chars(boxes[-1], 5, 'mario')
        #     # Luigi
        #     add_box_chars(boxes[-1], 5, 'luigi')
        # elif lang_code == 'jp':
        #     # マリオ
        #     add_box_chars(boxes[-1], 3, 'mario')
        #     # ルイージ
        #     add_box_chars(boxes[-1], 4, 'luigi')
        # else:
        #     raise ValueError("Unsupported lang_code for this escape sequence")
    elif escape_bytes == b'\x05\x00\x00\x01\x00':
        text = '<Mr. Plaaayer naaame>'
        lookup['msg_in_msg'][message_id] = dict(
            _placeholder=text,
            mario="System_PlayerName001",
            luigi="System_PlayerName101",
        )
        
        # TODO: Remove?
        # if lang_code == 'us':
        #     # Mr. Maaario
        #     add_box_chars(boxes[-1], 11, 'mario')
        #     # Mr. Luiiiigiii
        #     add_box_chars(boxes[-1], 14, 'luigi')
        # elif lang_code == 'jp':
        #     # マリオさ～～ん
        #     add_box_chars(boxes[-1], 7, 'mario')
        #     # ルイージさ～～ん
        #     add_box_chars(boxes[-1], 8, 'luigi')
        # else:
        #     raise ValueError("Unsupported lang_code for this escape sequence")
    elif escape_bytes[0] == 6:
        # A number. In general we don't know how many characters will be
        # added... it's message dependent and even case dependent beyond
        # that (e.g. which level a Hungry Luma is in). But we have a
        # structured way of handling case dependent numbers/names, and we'll
        # do that for the most important messages.
        if message_id in lookup['numbers_names']:
            # Make a copy with the dict constructor so that modifications
            # don't ruin the lookup.
            d = dict(lookup['numbers_names'][message_id])
            nn_type = d.pop('_type')
            if nn_type == 'text':
                text = d
                chars_by_case = dict([(case, len(t)) for case, t in d.items()])
                add_to_box(boxes[-1], 'chars', chars_by_case)
            elif nn_type == 'message':
                # Must fill this in with the contents of another message.
                # But we don't know what order the messages are processed
                # in, so we'll do this later once we've gone through all
                # the messages once.
                text = d['_placeholder']
                lookup['msg_in_msg'][message_id] = d
            else:
                raise ValueError("Unsupported numbers_names type: "+nn_type)
            # TODO: Remove?
            # cases = d[lang_code]
            # for case_name, chars in cases.items():
            #     add_box_chars(boxes[-1], chars, case_name)
        else:
            text = '<Number>'
    elif escape_bytes[0] == 7:
        # A name. Again, case by case basis, and we'll cover just the most
        # important messages.
        if message_id in lookup['numbers_names']:
            d = dict(lookup['numbers_names'][message_id])
            nn_type = d.pop('_type')
            if nn_type == 'text':
                text = d
                chars_by_case = dict([(case, len(t)) for case, t in d.items()])
                add_to_box(boxes[-1], 'chars', chars_by_case)
            elif nn_type == 'message':
                text = d['_placeholder']
                lookup['msg_in_msg'][message_id] = d
            else:
                raise ValueError("Unsupported numbers_names type: "+nn_type)
            # TODO: Remove?
            # cases = d[lang_code]
            # for case_name, chars in cases.items():
            #     add_box_chars(boxes[-1], chars, case_name)
        else:
            text = '<Name>'
    elif escape_bytes == b'\x09\x00\x05':
        text = 'xx:xx:xx'
        add_to_box(boxes[-1], 'chars', len(text))
    elif escape_bytes[:3] == b'\xFF\x00\x00':
        # Text color.
        color_byte = escape_bytes[3]
        color_type = lookup['colors'][color_byte]
        if display_colors:
            text = '<' + color_type + ' color>'
        else:
            text = ''
    elif escape_bytes[:3] == b'\xFF\x00\x02':
        # Japanese furigana (kanji reading help).
        kanji_count = struct.unpack('B', escape_bytes[3:4])[0]
        furigana_bytes = escape_bytes[4:-1]
        furigana_str = furigana_bytes.decode('utf-16be')
        if display_furigana:
            text = '<' + furigana_str + '>'
        else:
            text = ''
    else:
        # Unknown escape sequence.
        text = \
            "<Unknown escape " + binascii.hexlify(escape_bytes).decode() + ">"
        
    add_to_box(boxes[-1], 'text', text)
    return boxes
    
    
def compute_box_length(box, lang_code):
    f32 = np.float32
    char_alpha_req = 0.9
    if lang_code == 'usenglish':
        fade_rate = 0.4375
    elif lang_code == 'jpjapanese':
        fade_rate = 0.35
    else:
        raise ValueError("Unsupported language code: " + str(lang_code))
        
    alpha_req = (f32(box['chars']) * f32(char_alpha_req)) + f32(1)
    char_fade_length = math.floor(alpha_req / f32(fade_rate))
    box['length'] = box['pause_length'] + char_fade_length
    
    
def boxes_to_display(boxes):
    box_lines = []
    for box in boxes:
        if 'chars' not in box:
            # Box has multiple cases
            case_strs = []
            for case, box_for_case in box.items():
                if case == '_placeholder':
                    continue
                case_strs.append("{}: {} length, {} chars".format(
                    case, box_for_case['length'], box_for_case['chars']
                ))
            # Alphabetize the cases
            case_strs.sort()
            box_lines.append('{' + ', '.join(case_strs) + '}')
        else:
            box_lines.append("{} length, {} chars".format(
                box['length'], box['chars']
            ))
    s = "\n".join(box_lines)
    return s
    
    
def compute_base_message_frames(box_lengths, forced_slow):
    
    if forced_slow:
        base = box_lengths[0]
        
        for box_len in box_lengths[1:]:
            base += box_len
    else:
        # Holding A speeds up text scroll by 3x.
        base = math.ceil(box_lengths[0] / 3)
        
        for box_len in box_lengths[1:]:
            # The A press on the previous box required you to release A, and
            # it takes 12 frames of holding A before the text starts to speed
            # up. So the first 10 frames must be at slow speed.
            if box_len > 10:
                base += 10
                base += math.ceil((box_len-10) / 3)
            else:
                base += box_len
                
    # At the end of each box, there's a 2 frame delay
    # between the end of the text and when you can close that
    # text box with an A press.
    # The 1st frame is just a gap, and the 2nd frame comes from having
    # to press A for 2 frames.
    base += 2 * len(box_lengths)
                
    return base
    
    
def compute_message_frames(message, lookup):

    # Compute frames for the entire message, from start of first box's
    # frames (just before the 1st frame) to end of last box's frames.
    # Assume fast speed (holding A) for as long as possible.
    #
    # Note that we can't compute the final number of frames in general, due
    # to factors like box transition error. We'll just put in as much info as
    # we can to let another application determine the final number of frames.
    
    base_d = dict()
    
    base_d['num_boxes'] = len(message['boxes'])
    
    additional_factors = []
    if "<Number>" in message['text_display']:
        additional_factors.append("<Number>")
    if '<Name>' in message['text_display']:
        additional_factors.append("<Name>")
    if additional_factors != []:
        base_d['additional_factors'] = additional_factors
        
    animation_time = lookup['animation_times'].get(message['id'], None)
    if animation_time is not None:
        base_d['animation_time'] = animation_time
        
    forced_slow = message['id'] in lookup['forced_slow']
    base_d['forced_slow'] = forced_slow
    
    message_cases = []
    for box in message['boxes']:
        if 'chars' not in box:
            # box has cases.
            # Add box cases to running list of message cases 
            message_cases.extend(list(box.keys()))
            # Remove dupes
            message_cases = list(set(message_cases))
            
    if len(message_cases) > 0:
        frames = dict()
        frames_disp_lines = []
        
        for case_name in message_cases:
            frames[case_name] = dict(base_d)
            box_lengths = [
                box[case_name]['length']
                if 'length' not in box
                else box['length']
                for box in message['boxes']
            ]
            base = compute_base_message_frames(
                box_lengths, forced_slow
            )
            frames[case_name]['base'] = base
            
            if case_name == '_placeholder':
                continue
            frames_disp_lines.append(
                "{}: {}".format(
                    case_name,
                    message_frames_to_display(frames[case_name]),
                )
            )
        frames_display = "\n".join(sorted(frames_disp_lines))
        
    else:
        frames = dict(base_d)
        box_lengths = [box['length'] for box in message['boxes']]
        base = compute_base_message_frames(
            box_lengths, forced_slow
        )
        frames['base'] = base
        frames_display = message_frames_to_display(frames)
        
    message['frames'] = frames
    message['frames_display'] = frames_display
    
    
# TODO: Remove?
# def compute_message_frames(
#     box_lengths, message_text, forced_slow, animation_time):

#     # Compute frames for the entire message, from start of first box's
#     # frames (just before the 1st frame) to end of last box's frames.
#     # Assume fast speed (holding A) for as long as possible.
#     #
#     # Note that we can't compute the final number of frames in general, due
#     # to factors like box transition error. We'll just put in as much info as
#     # we can to let another application determine the final number of frames.
    
#     d = dict()
    
#     if forced_slow:
#         base = box_lengths[0]
        
#         for box_len in box_lengths[1:]:
#             # At the end of the previous box, there's a minimum 2 frame delay
#             # between the end of that text box and when this text box starts
#             # with your A press.
#             # The 1st frame is just a gap, and the 2nd frame comes from having
#             # to press A for 2 frames.
#             base += 2
#             base += box_len
#     else:
#         # Holding A speeds up text scroll by 3x.
#         base = math.ceil(box_lengths[0] / 3)
        
#         for box_len in box_lengths[1:]:
#             # Same 2 frame gap, and...
#             base += 2
#             # The A press on the previous box required you to release A, and
#             # it takes 12 frames of holding A before the text starts to speed
#             # up. So the first 10 frames must be at slow speed.
#             base += 10
#             if box_len > 10:
#                 base += math.ceil((box_len-10) / 3)
#             else:
#                 base += box_len
                
#     d['base'] = base
    
#     num_boxes = len(box_lengths)
#     if num_boxes > 1:
#         d['box_transitions'] = num_boxes - 1
        
#     additional_factors = []
#     if "<Number>" in message_text:
#         additional_factors.append("<Number>")
#     if '<Name>' in message_text:
#         additional_factors.append("<Name>")
#     if additional_factors != []:
#         d['additional_factors'] = additional_factors
        
#     if animation_time is not None:
#         d['animation_time'] = animation_time
        
#     return d
    
    
def message_frames_to_display(d):
    s = str(d['base'])
    s += " + {}A".format(d['num_boxes'])
    if 'additional_factors' in d:
        for factor in d['additional_factors']:
            s += " + {}'s frames".format(factor)
    if 'animation_time' in d:
        s += '\n(Cutscene: {})'.format(d['animation_time'])
    return s
    
    
def print_message_field_examples(
    messages, key, label, value_fmt='{}'):

    examples = [24,181,250,351,453,633,1942]
    s = "Example {}:\n".format(label)
    for ex in examples:
        s += "({})\n{}\n".format(str(ex), value_fmt.format(
            messages[ex][key]
        ))
    print(s)


def read_message_params(bmg, tbl, lang_code, all_messages):
    if all_messages is None:
        # No existing all_messages structure, so this is the first language
        # we're processing.
        all_messages = []
        first = True
    else:
        first = False
        
    # This language's messages only. We'll merge this into all_messages later.
    messages = []
    
    num_messages = struct.unpack('>I', tbl.read(4))[0]
    print("Number of messages: " + str(num_messages))
    unknown = tbl.read(0x24)
    
    for i in range(num_messages):
        message_index = struct.unpack('>I', tbl.read(4))[0]
        assert(message_index == i)
        message_id_offset = struct.unpack('>I', tbl.read(4))[0]
        messages.append(dict(id_offset=message_id_offset))
    print_message_field_examples(
        messages, 'id_offset', "message ID offsets", '{:04x}'
    )
    
    for i in range(num_messages):
        if i < num_messages - 1:
            id_offset = messages[i]['id_offset']
            next_id_offset = messages[i+1]['id_offset']
            message_id = tbl.read(next_id_offset - id_offset - 1)
            # One zero byte
            tbl.read(1)
        else:
            message_id = b''
            byte = tbl.read(1)
            # Read single bytes until a zero byte is reached
            while byte != b'\x00':
                message_id += byte
                byte = tbl.read(1)
        messages[i]['id'] = message_id.decode('ascii')
    print_message_field_examples(
        messages, 'id', "message IDs"
    )
    
    header = bmg.read(0x20)
    
    inf1_magic_constant = bmg.read(4)
    assert(inf1_magic_constant == b'INF1')
    inf1_section_size = struct.unpack('>I', bmg.read(4))[0]
    inf1_num_messages = struct.unpack('>H', bmg.read(2))[0]
    assert(num_messages == inf1_num_messages)
    inf1_item_size = struct.unpack('>H', bmg.read(2))[0]
    print("Item size: " + str(inf1_item_size))
    blank_bytes = bmg.read(4)
    
    for i in range(num_messages):
        item_bytes = bytearray(bmg.read(inf1_item_size))
        messages[i]['text_offset'] = \
            struct.unpack('>I', item_bytes[:4])[0]
        item_hex_str = ' '.join(format(x, '02x') for x in item_bytes)
        messages[i]['inf1_item'] = item_hex_str
    print_message_field_examples(
        messages, 'inf1_item', "INF1 items"
    )
    blank_bytes = bmg.read(16)
    
    if first:
        for m in messages:
            all_messages.append({lang_code: m})
    else:
        for i, m in enumerate(messages):
            all_messages[i][lang_code] = m
    
    return all_messages
    
    
def process_messages(bmg, lang_code, all_messages, lookup):
    
    # Assume that we just called read_message_params on this bmg file
    # and are at the beginning of the DAT1 section.
    dat1_magic_constant = bmg.read(4)
    assert(dat1_magic_constant == b'DAT1')
    dat1_section_size = struct.unpack('>I', bmg.read(4))[0]
    dat1_text_start = bmg.tell()
    
    msg_id_lookup = dict()
    
    
    # Fill in box information for each message.
    
    for i, m in enumerate(all_messages):
        
        m = m[lang_code]
        msg_id_lookup[m['id']] = m
            
        text_offset = m['text_offset']
        if text_offset == 0:
            m['text_pos'] = None
            m['text_display'] = "<Null message>"
            m['boxes'] = None
            continue
        
        message_text_start = dat1_text_start + text_offset
        m['text_pos'] = format(
            message_text_start, '05x'
        )
        
        current_file_pos = bmg.tell()
        if message_text_start < current_file_pos:
            raise ValueError(
                "Messages seem to be out of order!"
                " Haven't been programmed to handle this."
            )
        elif message_text_start > current_file_pos:
            extra_bytes = message_text_start - current_file_pos
            print("** Reading {} extra bytes before message {}".format(
                extra_bytes, i
            ))
            unused = bmg.read(extra_bytes)
        
        # At this point the current file position matches the position of the
        # next message.
        boxes = [dict(chars=0, text="", pause_length=0)]
        byte_pair = bmg.read(2)
        
        # The message ends at the null character \x00\x00. So, read until that
        # character is found.
        
        if byte_pair == b'\x00\x00':
            m['text_display'] = "<Blank message>"
            m['boxes'] = None
            continue
        
        while byte_pair != b'\x00\x00':
            if byte_pair == b'\x00\x1A':
                # Escape sequence - this part is not normal text
                escape_size = struct.unpack('B', bmg.read(1))[0] - 3
                escape_bytes = bmg.read(escape_size)
                
                handle_escape_sequence(
                    escape_bytes, boxes, lookup, lang_code, m['id']
                )
            else:
                # Character in UTF-16 big endian
                char = byte_pair.decode('utf-16be')
                
                # A message box break seems to always be followed by a
                # newline character, but in this situation the newline
                # doesn't affect the time the box text takes to scroll.
                # So we won't count this newline as a character for our
                # purposes.
                # Note that at the start of a box, there is no possibility for
                # multiple cases yet, since we only know to add multiple cases
                # after a particular escape sequence (number, player name,
                # etc.). So that simplifies the check.
                newline_after_box_break = (
                    char == '\n' and 'text' in boxes[-1]
                    and boxes[-1]['text'] == ""
                )
                
                if not newline_after_box_break:
                    add_to_box(boxes[-1], 'text', char)
                    add_to_box(boxes[-1], 'chars', 1)
            byte_pair = bmg.read(2)
            
        m['boxes'] = boxes
        
        
    # A few messages depend on other messages' content to be completed.
    
    for msg_id, d in lookup['msg_in_msg'].items():
        msg_to_complete = msg_id_lookup[msg_id]
        text_to_replace = d['_placeholder']
        replacement_texts = dict()
        replacement_text_lengths = dict()
        
        for case, v in d.items():
            if case == '_placeholder':
                replacement_texts[case] = v
                replacement_text_lengths[case] = 0
                continue
            replacement_msg_id = v
            msg = msg_id_lookup[replacement_msg_id]
            # We'll assume each replacement message only has 1 box and 1 case.
            text = msg['boxes'][0]['text']
            # Build a dict of the replacement text for each case.
            # (Every known msg_in_msg instance also has multiple cases.)
            replacement_texts[case] = text
            # Build a dict of the replacement text length for each case.
            replacement_text_lengths[case] = len(text)
        
        for box in msg_to_complete['boxes']:
            # We'll assume that a box awaiting message completion does not
            # already have multiple cases established. If it did,
            # we'd likely have a case of multiple dimensions of cases, which
            # we don't know how to handle anyway.
            if 'text' not in box:
                continue
            if text_to_replace not in box['text']:
                continue
                
            # Count how many times the to-be-replaced text appears.
            num_occurrences = box['text'].count(text_to_replace)
            
            replacement_text_char_counts = dict()
            for case, length in replacement_text_lengths.items():
                replacement_text_char_counts[case] = length * num_occurrences
            
            # Update char counts and establish multiple cases in the box dict.
            add_to_box(box, 'chars', replacement_text_char_counts)
            
            # Now that the box dict has multiple cases, updating the text will
            # be easier.
            for case, box_for_case in box.items():
                box_for_case['text'] = box_for_case['text'].replace(
                    text_to_replace, replacement_texts[case]
                )
                
                
    # Complete the messages' information.
    
    for i, m in enumerate(all_messages):
        
        m = m[lang_code]
        boxes = m['boxes']
        
        if not boxes:
            # Blank/null message.
            # text_display was already handled in either case.
            m['boxes_display'] = "<N/A>"
            m['frames'] = None
            m['frames_display'] = "<N/A>"
            continue
        
        if 'text' not in box:
            print(list(box.keys()))
        box_texts = [
            box['_placeholder']['text']
            if 'text' not in box
            else box['text']
            for box in boxes
        ]
        m['text_display'] = '\n\n'.join(box_texts)
        
        message_cases = []
        
        for box in boxes:
            if 'chars' not in box:
                # Box has multiple cases.
                for case, box_for_case in box.items():
                    compute_box_length(box_for_case, lang_code)
                    message_cases.append(case)
                for case in message_cases:
                    if case not in box:
                        raise ValueError(
                            "Different boxes in a message have different cases!"
                            " Needs multiple dimensions of cases, and we don't"
                            " know how to handle that yet."
                        )
            else:
                compute_box_length(box, lang_code)
                
        m['boxes_display'] = boxes_to_display(boxes)
        
        compute_message_frames(m, lookup)
        
        # There's some values we don't really need anymore.
        m.pop('id_offset')
        m.pop('inf1_item')
        m.pop('text_pos')
        m.pop('text_offset')
        
        # TODO: Remove the below?
        
        # message_id = m['id']
        # forced_slow = message_id in lookup['forced_slow']
        # animation_time = lookup['animation_times'].get(message_id, None)
        
        # if len(message_cases) > 0:
        #     frames = dict()
        #     frames_disp_lines = []
        #     for case_name in message_cases:
        #         box_lengths = [
        #             box[case_name]['length']
        #             if 'length' not in box
        #             else box['length']
        #             for box in boxes
        #         ]
        #         frames[case_name] = compute_message_frames(
        #             box_lengths, message_text, forced_slow, animation_time
        #         )
        #         frames_disp_lines.append(
        #             "{}: {}".format(
        #                 case_name,
        #                 message_frames_to_display(frames[case_name]),
        #             )
        #         )
        #     frames_disp = "\n".join(sorted(frames_disp_lines))
        # else:
        #     box_lengths = [box['length'] for box in boxes]
        #     frames = compute_message_frames(
        #         box_lengths, message_text, forced_slow, animation_time
        #     )
        #     frames_disp = message_frames_to_display(frames)
            
        # m['frames'] = frames
        # m['frames_disp'] = frames_disp
        
        
    messages_for_lang = [m[lang_code] for m in all_messages]
    
    print_message_field_examples(
        messages_for_lang, 'text_display', "message text"
    )
    print_message_field_examples(
        messages_for_lang, 'boxes_display', "message boxes"
    )
    print_message_field_examples(
        messages_for_lang, 'frames_display', "message frames"
    )
    
    return all_messages



if __name__ == '__main__':
    
    languages = []
    reader = csv.reader(open('languages.txt', 'r'), delimiter=',')
    for row in reader:
        lang_code = row[0]
        message_bmg_directory = row[1]
        languages.append(dict(code=lang_code, directory=message_bmg_directory))
    
    messages = None
    lookup = make_lookup()
    
    # Make message objs
    for n, language in enumerate(languages, 1):
        bmg_filename = os.path.join(language['directory'], 'message.bmg')
        tbl_filename = os.path.join(language['directory'], 'messageid.tbl')
        with open(bmg_filename, 'rb') as bmg, open(tbl_filename, 'rb') as tbl:
            # Add this language's data to the messages obj
            messages = read_message_params(bmg, tbl, language['code'], messages)
            messages = process_messages(
                bmg, language['code'], messages, lookup
            )
            
            
    first_lang_code = languages[0]['code']
    
    # Write CSV file - for a human readable spreadsheet
    csv_columns = [
        ('boxes', 'boxes_display'),
        ('frames', 'frames_display'),
        ('text', 'text_display'),
    ]
    headers = ['id']
    for language in languages:
        for csv_key, dict_key in csv_columns:
            headers.append(language['code'] + ' ' + csv_key)
    # newline='' prevents tons of extra blank rows from being written
    with open('messages.csv', 'w', newline='') as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(headers)
        for message in messages:
            row = []
            row.append(message[first_lang_code]['id'])
            for language in languages:
                for csv_key, dict_key in csv_columns:
                    # Add the item to CSV, while removing from the dict
                    # so that it's not included in the JSON later.
                    row.append(message[language['code']].pop(dict_key))
            writer.writerow(row)
        
        
    # Write JS file (as "window.var = <messages as JSON>") - for webpage
    # programming.
    
    # Make the JSON an object indexed by message id
    json_to_write = dict([(m[first_lang_code]['id'], m) for m in messages])
    with open('../../js/messages.js', 'w') as js_file:
        js_file.write("window.messages = " + json.dumps(json_to_write, js_file))
        
