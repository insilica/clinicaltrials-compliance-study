import pandas as pd
import graphviz

'''
This script re-creates Fig 1 from the Anderson et al paper
"Compliance with Results Reporting at ClinicalTrials.gov"

Given csv file with below columns to create table, with path `input_path` created with 
- 'position' {A, B, C, D, E}
- 'number' {int}
- 'label' {str}

Outputs svg of prisma flowchart
'''


# Defines Font to use for figure, input path of csv, output path of SVG (without suffix).

font_family = 'Tahoma'   # 'Tahoma' 'Consolas' 'Courier' 'Menlo' 
input_path = 'pseudo_table_data.csv' 
output_path = 'prisma_flowchart_figure' 


def wrap_text(text, width, add_tabbing=False, tabbing_size=3):
    words = text.split()  # Split the text into words
    current_line = ""     # Initialize an empty string for the current line
    result = ""           # Initialize an empty string for the final result
    
    tabbing = ' '*tabbing_size if add_tabbing else ''

    for word in words:
        # Check if adding the next word would exceed the width
        if len(current_line) + len(word) + 1 <= width:  # +1 for the space
            # If it fits, add the word to the current line
            if current_line:
                current_line += " " + word
            else:
                current_line = word
        else:
            # If it doesn't fit, add the current line to the result and start a new line
            result += current_line + "\n" + tabbing  # tabbing new lines
            current_line = word

    # Add the last line to the result
    result += current_line
    
    return result

def generate_nodes(df):
    # Retrieve position column from csv as node identifier
    # Re-construct text label from all subsequent rows
    node_ids = df['position'].unique()
    texts, positions = [], []
    
    d_positions = {
        'A': (0, 0),
        'B': (1, 0),
        'C': (0, -1),
        'D': (1, -1),
        'E': (0, -2),
    }

    # Loop through nodes and create text string with line breaks
    for n in node_ids:
        sub_df = df.loc[df['position']==n]
        text = ''
        
        for i, x in sub_df.iterrows():
            number, label = x.number, x.label
            number = '{:,}'.format(number)
            
            pad_number = 9-len(str(number)) # pad number with spaces to the left
            
            sub_text = str(number) + ' ' + str(label)

            if n in ['B','D']:
                sub_text = wrap_text(sub_text, width=75, add_tabbing=True, tabbing_size=9) + '\l'
            text += ' '*pad_number + sub_text

        if n in ['A','C','E']:
            text = wrap_text(text, width=50)

        texts.append(text)
        
        position = d_positions[n]                   # get tuple
        position = f"{position[0]},{position[1]}!"  # generate string-form 
        positions.append(position)
        
    node_ids = node_ids.astype(str)
    
    return node_ids, texts, positions

def create_graph(input_path, output_path):

    df = pd.read_csv(input_path)

    ### The cleaning below would not be needed upon internal generation of csv, but for the manual template:
    df = df.dropna()

    # Retrieve node identifiers, positions, and text labels
    node_ids, texts, positions = generate_nodes(df)

    # Initialize a new directed graph
    dot = graphviz.Digraph(comment='PRISMA Flow Diagram with Left-Right Layout')

    # Set general graph attributes
    dot.attr(rankdir='LR', size='14', ratio='compress')
    
    # Create a subgraph for nodes A, C, E (left side)
    with dot.subgraph() as s:
        s.attr(rank='same')
        for node_id, text, position in zip(node_ids[::2], texts[::2], positions[::2]):
            s.node(node_id, text, shape='box', style='solid,', color='#898989', 
                     pos = position, width='2', height='1', 
                   fontname=font_family, fontsize='15', labeljust="l", align='left') 
        s.node('A1', '', shape='point', width='0', height='0')
        s.node('C1', '', shape='point', width='0', height='0')

    # Create a subgraph for nodes B, D (right side)
    with dot.subgraph() as t:
        t.attr(rank='same')
        for node_id, text, position in zip(node_ids[1::2], texts[1::2], positions[1::2]):
            t.node(node_id, text, shape='box', style='solid,', color='#898989', 
                     pos = position, width='2', height='1', 
                   fontname=font_family, fontsize='15', labeljust="l", align='left') 

    dot.edge('A', 'A1', minlen='2', weight='2', arrowhead='none', arrowsize='0.6')  # down
    dot.edge('A1', 'B', minlen='1', weight='5', arrowsize='0.6')                    # right
    dot.edge('A1', 'C', minlen='3',  weight='2', label=" ", arrowsize='0.6')        # down

    dot.edge('C', 'C1', minlen='2', weight='2', arrowhead='none', arrowsize='0.6')  # down
    dot.edge('C1', 'D', minlen='', weight='5', arrowsize='0.6')                     # right
    dot.edge('C1', 'E', minlen='3', weight='2', label=" ", arrowsize='0.6')         # down

    # Render the diagram as an SVG file
    dot.render(output_path, format='svg', cleanup=True)
    print(f"Figure saved to {output_path}.svg")
    
    return


if __name__ == '__main__':
    
    create_graph(input_path, output_path)
    
    
