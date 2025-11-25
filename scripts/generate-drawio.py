#!/usr/bin/env python3
"""
Generate draw.io XML diagram from AWS infrastructure
"""

import json
import subprocess
import xml.etree.ElementTree as ET
from xml.dom import minidom

def get_aws_resources():
    """Fetch AWS resources using AWS CLI"""
    resources = {
        'vpcs': [],
        'ec2_instances': [],
        's3_buckets': [],
        'iam_roles': [],
        'oidc_providers': []
    }

    # Get VPCs
    try:
        result = subprocess.run(
            ['aws', 'ec2', 'describe-vpcs', '--output', 'json'],
            capture_output=True, text=True, check=True
        )
        vpcs_data = json.loads(result.stdout)
        resources['vpcs'] = vpcs_data.get('Vpcs', [])
    except Exception as e:
        print(f"Error fetching VPCs: {e}")

    # Get EC2 instances
    try:
        result = subprocess.run(
            ['aws', 'ec2', 'describe-instances', '--output', 'json'],
            capture_output=True, text=True, check=True
        )
        ec2_data = json.loads(result.stdout)
        for reservation in ec2_data.get('Reservations', []):
            resources['ec2_instances'].extend(reservation.get('Instances', []))
    except Exception as e:
        print(f"Error fetching EC2: {e}")

    # Get S3 buckets
    try:
        result = subprocess.run(
            ['aws', 's3api', 'list-buckets', '--output', 'json'],
            capture_output=True, text=True, check=True
        )
        s3_data = json.loads(result.stdout)
        resources['s3_buckets'] = s3_data.get('Buckets', [])
    except Exception as e:
        print(f"Error fetching S3: {e}")

    # Get IAM roles
    try:
        result = subprocess.run(
            ['aws', 'iam', 'list-roles', '--output', 'json'],
            capture_output=True, text=True, check=True
        )
        iam_data = json.loads(result.stdout)
        # Filter out AWS-managed roles
        resources['iam_roles'] = [
            r for r in iam_data.get('Roles', [])
            if not r['RoleName'].startswith('AWS')
        ][:10]  # Limit to 10 for diagram clarity
    except Exception as e:
        print(f"Error fetching IAM roles: {e}")

    return resources

def create_drawio_xml(resources, output_file):
    """Generate draw.io XML from AWS resources"""

    # Create root mxfile element
    mxfile = ET.Element('mxfile', {
        'host': 'app.diagrams.net',
        'modified': '2025-11-24T00:00:00.000Z',
        'agent': 'AWS Infrastructure Generator',
        'version': '1.0',
        'type': 'device'
    })

    # Create diagram
    diagram = ET.SubElement(mxfile, 'diagram', {
        'id': 'aws-infrastructure',
        'name': 'AWS Infrastructure'
    })

    # Create mxGraphModel
    graph_model = ET.SubElement(diagram, 'mxGraphModel', {
        'dx': '1422',
        'dy': '794',
        'grid': '1',
        'gridSize': '10',
        'guides': '1',
        'tooltips': '1',
        'connect': '1',
        'arrows': '1',
        'fold': '1',
        'page': '1',
        'pageScale': '1',
        'pageWidth': '1600',
        'pageHeight': '900',
        'math': '0',
        'shadow': '0'
    })

    # Create root cells
    root = ET.SubElement(graph_model, 'root')
    ET.SubElement(root, 'mxCell', {'id': '0'})
    ET.SubElement(root, 'mxCell', {'id': '1', 'parent': '0'})

    cell_id = 2
    x_pos = 100
    y_pos = 100

    # Add VPC container
    if resources['vpcs']:
        vpc = resources['vpcs'][0]
        vpc_cidr = vpc.get('CidrBlock', 'N/A')
        vpc_id = vpc.get('VpcId', 'vpc-unknown')

        vpc_cell = ET.SubElement(root, 'mxCell', {
            'id': str(cell_id),
            'value': f'VPC\\n{vpc_id}\\n{vpc_cidr}',
            'style': 'swimlane;fillColor=#E8F5E9;strokeColor=#4CAF50;fontStyle=1',
            'vertex': '1',
            'parent': '1'
        })
        ET.SubElement(vpc_cell, 'mxGeometry', {
            'x': '50',
            'y': '50',
            'width': '1500',
            'height': '800',
            'as': 'geometry'
        })
        cell_id += 1
        vpc_parent = str(cell_id - 1)
    else:
        vpc_parent = '1'

    # Add EC2 instances
    ec2_x = 150
    ec2_y = 200
    for idx, instance in enumerate(resources['ec2_instances'][:8]):  # Max 8 for layout
        name = 'EC2 Instance'
        for tag in instance.get('Tags', []):
            if tag['Key'] == 'Name':
                name = tag['Value']

        instance_id = instance.get('InstanceId', 'unknown')
        instance_type = instance.get('InstanceType', 'unknown')
        state = instance.get('State', {}).get('Name', 'unknown')

        color = '#FF6B6B' if state == 'stopped' else '#4CAF50'

        cell = ET.SubElement(root, 'mxCell', {
            'id': str(cell_id),
            'value': f'{name}\\n{instance_id}\\n{instance_type}\\n({state})',
            'style': f'rounded=1;whiteSpace=wrap;html=1;fillColor={color};strokeColor=#333333;fontColor=#FFFFFF',
            'vertex': '1',
            'parent': vpc_parent
        })
        ET.SubElement(cell, 'mxGeometry', {
            'x': str(ec2_x + (idx % 4) * 250),
            'y': str(ec2_y + (idx // 4) * 150),
            'width': '200',
            'height': '100',
            'as': 'geometry'
        })
        cell_id += 1

    # Add S3 buckets (outside VPC)
    s3_x = 1200
    s3_y = 100
    for idx, bucket in enumerate(resources['s3_buckets'][:5]):  # Max 5
        bucket_name = bucket.get('Name', 'unknown')

        cell = ET.SubElement(root, 'mxCell', {
            'id': str(cell_id),
            'value': f'S3\\n{bucket_name}',
            'style': 'shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#FFE5B4;strokeColor=#FF8C00',
            'vertex': '1',
            'parent': '1'
        })
        ET.SubElement(cell, 'mxGeometry', {
            'x': str(s3_x),
            'y': str(s3_y + idx * 120),
            'width': '150',
            'height': '80',
            'as': 'geometry'
        })
        cell_id += 1

    # Add IAM roles
    iam_x = 150
    iam_y = 550
    for idx, role in enumerate(resources['iam_roles'][:6]):  # Max 6
        role_name = role.get('RoleName', 'unknown')

        cell = ET.SubElement(root, 'mxCell', {
            'id': str(cell_id),
            'value': f'IAM Role\\n{role_name}',
            'style': 'shape=hexagon;perimeter=hexagonPerimeter2;whiteSpace=wrap;html=1;fixedSize=1;fillColor=#B3E5FC;strokeColor=#0277BD',
            'vertex': '1',
            'parent': vpc_parent
        })
        ET.SubElement(cell, 'mxGeometry', {
            'x': str(iam_x + (idx % 3) * 280),
            'y': str(iam_y + (idx // 3) * 100),
            'width': '200',
            'height': '70',
            'as': 'geometry'
        })
        cell_id += 1

    # Add title
    title_cell = ET.SubElement(root, 'mxCell', {
        'id': str(cell_id),
        'value': 'AWS Infrastructure Diagram\\nAccount: 266735821834',
        'style': 'text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;whiteSpace=wrap;rounded=0;fontSize=20;fontStyle=1',
        'vertex': '1',
        'parent': '1'
    })
    ET.SubElement(title_cell, 'mxGeometry', {
        'x': '600',
        'y': '10',
        'width': '400',
        'height': '30',
        'as': 'geometry'
    })

    # Pretty print XML
    xml_str = ET.tostring(mxfile, encoding='unicode')
    dom = minidom.parseString(xml_str)
    pretty_xml = dom.toprettyxml(indent='  ')

    # Write to file
    with open(output_file, 'w') as f:
        f.write(pretty_xml)

    print(f"✅ Draw.io diagram generated: {output_file}")
    print(f"📊 Resources included:")
    print(f"   - {len(resources['vpcs'])} VPC(s)")
    print(f"   - {len(resources['ec2_instances'])} EC2 instance(s)")
    print(f"   - {len(resources['s3_buckets'])} S3 bucket(s)")
    print(f"   - {len(resources['iam_roles'])} IAM role(s)")

if __name__ == '__main__':
    import sys

    # Get output directory from command line or use default
    if len(sys.argv) > 1:
        output_dir = sys.argv[1]
    else:
        output_dir = '../output'

    print("🔍 Fetching AWS resources...")
    resources = get_aws_resources()

    output_file = f'{output_dir}/aws-infrastructure.drawio'
    print(f"📝 Generating draw.io diagram...")
    create_drawio_xml(resources, output_file)
    print(f"\n🎉 Done! Open {output_file} in draw.io to view and edit.")
