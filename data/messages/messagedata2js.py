# In: message files from an SMG1 disc
# Out: JSON data (as JS file) and CSV data about those messages and the
# time it takes to scroll through them


import argparse
import binascii
import collections
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
    
    lookup['forcedSlow'] = []
    reader = csv.reader(open('forced-slow-messages.txt', 'r'), delimiter=',')
    for row in reader:
        message_id = row[0]
        lookup['forcedSlow'].append(message_id)
            
    lookup['languageSpeeds'] = dict()
    reader = csv.reader(open('language-speeds.txt', 'r'), delimiter=',')
    for row in reader:
        lang_code = row[0]
        d = dict(alphaReq=float(row[1]), fadeRate=float(row[2]))
        lookup['languageSpeeds'][lang_code] = d
    
    lookup['numbersNames'] = dict()
    j = json.load(open('number-name-specifics.json', 'r'))
    for message_id, d in j.items():
        lookup['numbersNames'][message_id] = d
    
    lookup['animationTimes'] = dict()
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
            lookup['animationTimes'][message_id] = num_of_frames
    
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
    
def handle_escape_sequence(escape_bytes, boxes, lookup, message_id,
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
        
    elif escape_bytes == b'\x05\x00\x00\x01\x00':
        text = '<Mr. Plaaayer naaame>'
        lookup['msg_in_msg'][message_id] = dict(
            _placeholder=text,
            mario="System_PlayerName001",
            luigi="System_PlayerName101",
        )
        
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


def read_messages_from_disc_files(bmg, tbl):
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
    
    for i, m in enumerate(messages):
        if i < num_messages - 1:
            id_offset = m['id_offset']
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
        m['id'] = message_id.decode('ascii')
        
        # Don't need this anymore.
        m.pop('id_offset')
    print_message_field_examples(
        messages, 'id', "message IDs"
    )
    
    # Read bmg header.
    header = bmg.read(0x20)
    
    # Read bmg's INF1 section.
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
        messages[i]['content_offset'] = \
            struct.unpack('>I', item_bytes[:4])[0]
    # Read blank bytes at the end of the INF1 section.
    num_blank_bytes = inf1_section_size - 16 - inf1_num_messages*inf1_item_size
    blank_bytes = bmg.read(num_blank_bytes)
    
    # Read bmg's DAT1 section.
    dat1_magic_constant = bmg.read(4)
    assert(dat1_magic_constant == b'DAT1')
    dat1_section_size = struct.unpack('>I', bmg.read(4))[0]
    dat1_content_start = bmg.tell()
    
    for i, m in enumerate(messages):
        
        content_offset = m['content_offset']
        if content_offset == 0:
            # Message with no content location specified.
            m['content'] = None
            continue
            
        content_start = dat1_content_start + content_offset
        current_file_pos = bmg.tell()
        if content_start < current_file_pos:
            raise ValueError(
                "Messages seem to be out of order!"
                " Haven't been programmed to handle this."
            )
        elif content_start > current_file_pos:
            # Occasionally there are extra bytes between the end (null char) of
            # one message and the start of the next message. Read those
            # extra bytes in that case.
            num_extra_bytes = content_start - current_file_pos
            print("** Reading {} extra bytes before message {}".format(
                num_extra_bytes, i
            ))
            unused = bmg.read(num_extra_bytes)
            
        m['content'] = []
        text = ""
        
        # bmg.read() results in a bytes type.
        # To see an example of this type, try this in interpreter:
        # bytes('asdf', 'utf-16be')
        byte_pair = bmg.read(2)
        
        # The message ends at the null character \x00\x00. So, read until that
        # character is found.
        while byte_pair != b'\x00\x00':
            if byte_pair == b'\x00\x1A':
                # Escape sequence - this part is not normal text
                
                # Cut off the current text element if there is one.
                if text != "":
                    m['content'].append(text)
                    text = ""
                
                # Next 1 byte is the size of the entire escape sequence.
                # Subtract 3 (2 for the 00 1A, 1 for the size) to get the size
                # of the escape sequence data.
                escape_size = struct.unpack('B', bmg.read(1))[0] - 3
                # Next comes the escape sequence data.
                escape_bytes = bmg.read(escape_size)
                # Add the escape sequence data as a list of numbers
                # (byte values).
                m['content'].append([b for b in escape_bytes])
            else:
                # Character in UTF-16 big endian; decode and add it as a
                # UTF-8 character.
                char = byte_pair.decode('utf-16be')
                text += char
            byte_pair = bmg.read(2)
          
        # Add the final bit of text if there is one.
        if text != "":
            m['content'].append(text)
        
        # Don't need this anymore.
        m.pop('content_offset')
    
    return messages
    
    
def get_text_bytes(bytes_generator, num_bytes):
    bytes_gotten = bytes()
    for i in range(num_bytes):
        # Generator of a bytes object returns integers for
        # some reason, so have to wrap it back up into a bytes().
        bytes_gotten += bytes([next(bytes_generator)])
    return bytes_gotten
    
def process_messages(lang_code, messages, lookup):
    
    # TODO: Account for new m['content'] format
    # TODO: Include escape character handling
    # TODO: Include boxes char addition, including the non-affecting
    # line break after a box break. See this:
    #
    # # A message box break seems to always be followed by a
    # # newline character, but in this situation the newline
    # # doesn't affect the time the box text takes to scroll.
    # # So we won't count this newline as a character for our
    # # purposes.
    # # Note that at the start of a box, there is no possibility for
    # # multiple cases yet, since we only know to add multiple cases
    # # after a particular escape sequence (number, player name,
    # # etc.). So that simplifies the check.
    # newline_after_box_break = (
    #     char == '\n' and 'text' in boxes[-1]
    #     and boxes[-1]['text'] == ""
    # )
    #
    # if not newline_after_box_break:
    #     add_to_box(boxes[-1], 'text', char)
    #     add_to_box(boxes[-1], 'chars', 1)
    
    msg_id_lookup = dict()
    
    
    # Fill in box information for each message.
    
    for i, m in enumerate(messages):
        
        msg_id_lookup[m['id']] = m
        
        if m['bytes'] is None:
            m['text_display'] = "<Null message>"
            m['boxes'] = None
            continue
            
        # Make generator
        m_bytes = (b for b in m['bytes'])
        
        # At this point the current file position matches the position of the
        # next message.
        boxes = [dict(chars=0, text="", pause_length=0)]
        
        byte_pair = get_text_bytes(m_bytes, 2)
        
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
                escape_bytes = get_text_bytes(m_bytes, escape_size)
                
                handle_escape_sequence(
                    escape_bytes, boxes, lookup, m['id']
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
            
            byte_pair = get_text_bytes(m_bytes, 2)
            
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
    
    for i, m in enumerate(messages):
        
        boxes = m['boxes']
        
        if not boxes:
            # Blank/null message.
            # text_display was already handled in either case.
            m['boxes_display'] = "<N/A>"
            m['frames'] = None
            m['frames_display'] = "<N/A>"
            continue
        
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
        
    
    print_message_field_examples(
        messages, 'text_display', "message text"
    )
    print_message_field_examples(
        messages, 'boxes_display', "message boxes"
    )
    print_message_field_examples(
        messages, 'frames_display', "message frames"
    )
    
    return messages



if __name__ == '__main__':
    
    languages = []
    reader = csv.reader(open('language-files.txt', 'r'), delimiter=',')
    for row in reader:
        lang_code = row[0]
        message_bmg_directory = row[1]
        languages.append(dict(code=lang_code, directory=message_bmg_directory))
    
    # messages is a dict whose entries are auto-initialized to an empty dict.
    # Will be indexed by message id, and then by language code.
    messages = collections.defaultdict(dict)
    
    for language in languages:
        
        messages = dict()
        
        # Read this language's messages from this language's disc files
        lang_code = language['code']
        bmg_filename = os.path.join(language['directory'], 'message.bmg')
        tbl_filename = os.path.join(language['directory'], 'messageid.tbl')
        with open(bmg_filename, 'rb') as bmg, open(tbl_filename, 'rb') as tbl:
            messages_list = read_messages_from_disc_files(bmg, tbl)
            
        for m in messages_list:
            messages[m['id']] = m['content']
            
        # Write message data in a JS file.
        msg_filename = '../../js/messages/{code}.js'.format(code=lang_code)
        # Make necessary directories if they don't exist. 
        os.makedirs(os.path.dirname(msg_filename), exist_ok=True)
        with open(msg_filename, 'w', encoding='utf-8') as f:
            f.write(
                r"if (window.messages === undefined) {window.messages = {};}"
            )
            f.write("\n")
            f.write(
                "window.messages.{code} = {message_json};".format(
                    code=lang_code,
                    message_json=json.dumps(messages, ensure_ascii=False),
                )
            )
    
    # Make message-data lookup structure with various info (color/icon escape
    # codes, which messages force slow speed, etc.)
    lookup = make_lookup()
    lookup_filename = '../../js/messagelookup.js'
    with open(lookup_filename, 'w', encoding='utf-8') as f:
        f.write(
            "window.messageLookup = {lookup_json};".format(
                lookup_json=json.dumps(lookup, ensure_ascii=False),
            )
        )
    
        
    raise ValueError("Rest of this program doesn't work anymore, but will be ported")
         
    
         
    for language in languages:
        messages[language['code']] = process_messages(
            language['code'], messages[language['code']], lookup
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
        js_file.write("window.messages = " + json.dumps(json_to_write))
        
