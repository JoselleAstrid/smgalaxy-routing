import csv
import json



if __name__ == '__main__':
    
    items = dict()
    reader = csv.reader(open('itemdetails.csv', 'r'), delimiter=',')
    
    # Skip header row
    next(reader)
    
    for row in reader:
        # Google Docs LOVES to randomly insert newlines at the start/end of
        # cells, so defend against that.
        row = [cell.strip() for cell in row]
        
        item_name = row[0]
        item_type = row[1]
        requirements = row[2].splitlines() if row[2] else []
        follows = row[3].splitlines() if row[3] else []
        start_location = row[4] if row[4] else None
        end_location = row[5] if row[5] else None
        star_name = row[6] if row[6] else None
        
        items[item_name] = dict(
            requirements = requirements,
            follows = follows,
            start_location = start_location,
            end_location = end_location,
            star_name = star_name,
        )
        # type is a Python keyword, so assign this separately
        items[item_name]['type'] = item_type
    
    with open('../js/itemdetails.js', 'w') as js_file:
        js_file.write("window.itemDetails = " + json.dumps(items, js_file))