# data-analyst-portfolio

## Setup Instructions

1. Clone the repository
2. Install dependencies:
```bash
   pip install -r requirements.txt
```

3. Set up your database:
```bash
   # Create PostgreSQL database
   createdb nordic_fashion_bi
```

4. Configure environment variables:
```bash
   cp .env.example .env
   # Edit .env with your database credentials
```

5. Run the application:
```bash
   python app.py
```

## Environment Variables

- `DATABASE_URL`: PostgreSQL connection string
- See `.env.example` for required variables
