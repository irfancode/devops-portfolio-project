class Item:
    def __init__(self, name, description='', status='active'):
        self.id = None
        self.name = name
        self.description = description
        self.status = status
        self.created_at = None
        self.updated_at = None

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'status': self.status,
            'created_at': self.created_at,
            'updated_at': self.updated_at
        }

    @classmethod
    def from_dict(cls, data):
        item = cls(
            name=data.get('name', ''),
            description=data.get('description', ''),
            status=data.get('status', 'active')
        )
        item.id = data.get('id')
        item.created_at = data.get('created_at')
        item.updated_at = data.get('updated_at')
        return item
