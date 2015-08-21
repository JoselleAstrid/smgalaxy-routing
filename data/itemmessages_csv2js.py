import csv
import json
import re



if __name__ == '__main__':
    
    items = dict()
    brackets_regex = re.compile(r'(.+)\[(.+)\]')
    reader = csv.reader(open('itemmessages.csv', 'r'), delimiter=',')
    
    for row in reader:
        # Google Docs LOVES to randomly insert newlines at the start/end of
        # cells, so defend against that.
        row = [cell.strip() for cell in row]
        
        item_name = row[0]
        message_cells = row[1:]
        messages = []
        
        for message in message_cells:
            
            if message == "" or message == "<None>":
                # Done with this item
                break
                
            d = dict()
            
            if message.endswith("(SKIPPABLE)"):
                message = message.rstrip("(SKIPPABLE)")
                d['skippable'] = True
                
            match = brackets_regex.match(message)
            if match:
                m_id = match.group(1)
                d['case'] = match.group(2)
            else:
                m_id = message
                
            # Check for conditional IDs, such as
            # {mario: DiskGardenZone_LuigiEvent001,
            # luigi: DiskGardenZone_LuigiEvent002}
            if m_id.startswith('{') and m_id.endswith('}'):
                m_id = m_id.lstrip('{').rstrip('}')
                case_strs = [s.strip() for s in m_id.split(',')]
                cases = dict()
                for s in case_strs:
                    k, v = [x.strip() for x in s.split(':')]
                    cases[k] = v
                d['id'] = cases
            else:
                d['id'] = m_id
                
            messages.append(d)
            
        items[item_name] = messages
    
    with open('../js/itemmessages.js', 'w') as js_file:
        js_file.write("window.itemMessages = " + json.dumps(items, js_file))