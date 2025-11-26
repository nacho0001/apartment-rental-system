from flask import Flask, render_template, request, redirect, url_for, flash, session
import sqlite3
from werkzeug.security import generate_password_hash, check_password_hash
from sqlite3 import IntegrityError
from functools import wraps

app = Flask(__name__)
# IMPORTANT: Use a complex, randomly generated key in production
app.secret_key = "secret_key"
# NOTE: Please change this line in a production environment!

# ---------------- Database Connection ----------------
def get_db_connection():
    conn = sqlite3.connect('database.db')
    # Enable foreign key enforcement for data integrity
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    return conn

# ---------------- Initialize Database ----------------
def init_db():
    conn = get_db_connection()
    
    # 1. Users Table (for managers/admins)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            phone TEXT, 
            password TEXT NOT NULL
        )
    ''')
    
    # 2. Apartments Table (the main listing content)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS apartments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            bedrooms INTEGER,
            bathrooms INTEGER,
            location TEXT NOT NULL,
            rent REAL
        )
    ''')

    # 3. Tenants Table (for tenant management)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS tenants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            apartment_id INTEGER UNIQUE, -- Added UNIQUE constraint for 1 tenant per apt
            lease_start TEXT,
            FOREIGN KEY (apartment_id) REFERENCES apartments (id) ON DELETE SET NULL
        )
    ''')

    # ------------------ SPECIALIZATION ADDITION ------------------
    # 4. Rent Payments Table (for tracking financial transactions)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS rent_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL,
            amount_paid REAL NOT NULL,
            payment_date TEXT NOT NULL,
            payment_for_month TEXT NOT NULL, -- Format: YYYY-MM
            status TEXT NOT NULL, -- e.g., 'Paid', 'Partial', 'Late'
            FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
        )
    ''')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_tenant_id ON rent_payments (tenant_id)')
    # -------------------------------------------------------------
    
    # Insert Sample Apartment Data (Only if the table is empty)
    cursor_apt = conn.execute('SELECT COUNT(*) FROM apartments')
    if cursor_apt.fetchone()[0] == 0:
        print("Inserting sample apartment data...")
        sample_apartments = [
            ('Goro Deluxe Apt', 3, 2, 'Goro', 15000.00),
            ('Kazanchis Studio', 1, 1, 'Kazanchis', 8000.00),
            ('Bole Road Family Home', 4, 3, 'Bole', 25000.00)
        ]
        conn.executemany(
            'INSERT INTO apartments (name, bedrooms, bathrooms, location, rent) VALUES (?, ?, ?, ?, ?)',
            sample_apartments
        )
        
        # Insert a sample tenant to demonstrate occupied/available status
        conn.execute('INSERT INTO tenants (fullName, phone, email, apartment_id, lease_start) VALUES (?, ?, ?, ?, ?)',
                     ('Abebe Kebede', '0911223344', 'abebek@example.com', 1, '2024-01-01'))

    # Insert Sample Payment Data (Only if the table is empty AND tenant exists)
    cursor_pay = conn.execute('SELECT COUNT(*) FROM rent_payments')
    if cursor_pay.fetchone()[0] == 0:
        tenant_id_goro = conn.execute('SELECT id FROM tenants WHERE apartment_id = 1').fetchone()
        if tenant_id_goro:
            print("Inserting sample payment data...")
            conn.execute(
                'INSERT INTO rent_payments (tenant_id, amount_paid, payment_date, payment_for_month, status) VALUES (?, ?, ?, ?, ?)',
                (tenant_id_goro['id'], 15000.00, '2024-11-15', '2024-11', 'Paid')
            )
    
    conn.commit()
    conn.close()

# ---------------- Utility Functions ----------------

def login_required(f):
    """Decorator to check if user is logged in before accessing a route."""
    @wraps(f) # Use functools.wraps for better decorator function handling
    def wrapper(*args, **kwargs):
        if 'logged_in' not in session or not session['logged_in']:
            flash("You must be logged in to view this page.", "error")
            return redirect(url_for('home'))
        return f(*args, **kwargs)
    return wrapper

def get_available_apartments(conn):
    """Fetches a list of apartments not currently assigned to a tenant."""
    # This query ensures only apartments NOT associated with any tenant are returned.
    return conn.execute('''
        SELECT a.id, a.name, a.bedrooms, a.bathrooms, a.location, a.rent
        FROM apartments a
        LEFT JOIN tenants t ON a.id = t.apartment_id
        WHERE t.apartment_id IS NULL
        ORDER BY a.name
    ''').fetchall()

# ---------------- Core Routes ----------------

@app.route('/')
def home():
    conn = get_db_connection()
    # Fetch ONLY apartments that are not currently assigned to a tenant using the utility function
    apartments = get_available_apartments(conn)
    conn.close()
    
    return render_template('index.html', apartments=apartments)

# ---------------- User Authentication ----------------

@app.route('/register', methods=['POST'])
def register():
    fullName = request.form['fullName']
    email = request.form['email']
    phone = request.form['phone']
    password = request.form['password']
    
    # BASIC VALIDATION
    if not all([fullName, email, phone, password]):
        flash("All fields are required for registration.", "error")
        return redirect(url_for('home'))

    hashed_password = generate_password_hash(password)

    conn = get_db_connection()
    try:
        conn.execute('INSERT INTO users (fullName, email, phone, password) VALUES (?, ?, ?, ?)',
                     (fullName, email, phone, hashed_password))
        conn.commit()
        
        flash("Registration successful! Please log in.", "success")
        
    except IntegrityError:
        flash("Registration failed. That email is already in use.", "error")
        
    finally:
        conn.close()
        
    return redirect(url_for('home'))

@app.route('/login', methods=['POST'])
def login():
    email = request.form.get('loginEmail')
    password = request.form.get('loginPassword')

    if not email or not password:
        flash("Please provide both email and password.", "error")
        return redirect(url_for('home'))

    conn = get_db_connection()
    user = conn.execute('SELECT * FROM users WHERE email = ?', (email,)).fetchone()
    conn.close()

    if user and check_password_hash(user['password'], password):
        # Set session variables to log the user in
        session['logged_in'] = True
        session['user_id'] = user['id']
        session['user_name'] = user['fullName']
        
        flash(f"Welcome back, {user['fullName']}!", "success")
        return redirect(url_for('dashboard')) 
    else:
        flash("Invalid email or password", "error")
        return redirect(url_for('home'))

@app.route('/logout')
def logout():
    session.clear() 
    flash("You have been logged out successfully.", "success")
    return redirect(url_for('home'))

# ---------------- Dashboard & Management Routes ----------------

@app.route('/dashboard')
@login_required
def dashboard():
    conn = get_db_connection()
    
    # 1. Total Apartment Count
    total_apartments = conn.execute('SELECT COUNT(id) FROM apartments').fetchone()[0]
    
    # 2. Total Occupied Units
    # Count how many *unique* apartments currently have a tenant assigned
    occupied_units = conn.execute('SELECT COUNT(apartment_id) FROM tenants WHERE apartment_id IS NOT NULL').fetchone()[0]
    
    # 3. Total Tenant Count (Total people under management)
    total_tenants = conn.execute('SELECT COUNT(id) FROM tenants').fetchone()[0]

    # ------------------ SPECIALIZATION METRICS ------------------
    # Total Collected Rent (Lifetime)
    collected_rent = conn.execute('SELECT SUM(amount_paid) FROM rent_payments').fetchone()[0] or 0.0
    
    # Expected Monthly Rent Roll (Based on current occupancy)
    expected_monthly_rent = conn.execute('''
        SELECT SUM(a.rent) 
        FROM apartments a
        JOIN tenants t ON a.id = t.apartment_id
        WHERE t.apartment_id IS NOT NULL 
    ''').fetchone()[0] or 0.0
    # -------------------------------------------------------------
    
    conn.close()
    
    # Calculate available units
    available_apartments = total_apartments - occupied_units

    # Pass the metrics to the dashboard template
    return render_template('dashboard.html', 
        user_name=session['user_name'],
        total_apartments=total_apartments,
        available_apartments=available_apartments,
        total_tenants=total_tenants,
        collected_rent=collected_rent, # Added for specialization display
        expected_monthly_rent=expected_monthly_rent # Added for specialization display
    )

# ------------------ SPECIALIZATION ROUTE: FINANCIAL OVERVIEW ------------------

@app.route('/financial_overview')
@login_required
def financial_overview():
    conn = get_db_connection()
    
    # Total Collected Rent (Lifetime)
    collected_rent = conn.execute('SELECT SUM(amount_paid) FROM rent_payments').fetchone()[0] or 0.0

    # Expected Monthly Rent Roll (Based on current occupancy)
    expected_monthly_rent = conn.execute('''
        SELECT SUM(a.rent) 
        FROM apartments a
        JOIN tenants t ON a.id = t.apartment_id
        WHERE t.apartment_id IS NOT NULL 
    ''').fetchone()[0] or 0.0
    
    # Last 10 Payments (Recent activity)
    recent_payments = conn.execute('''
        SELECT 
            rp.amount_paid, 
            rp.payment_date, 
            rp.payment_for_month,
            rp.status,
            t.fullName AS tenant_name, 
            a.name AS apartment_name
        FROM rent_payments rp
        JOIN tenants t ON rp.tenant_id = t.id
        LEFT JOIN apartments a ON t.apartment_id = a.id
        ORDER BY rp.payment_date DESC
        LIMIT 10
    ''').fetchall()
    
    conn.close()
    
    return render_template('financial_overview.html',
        collected_rent=collected_rent,
        expected_monthly_rent=expected_monthly_rent,
        recent_payments=recent_payments
    )

# ------------------------------------------------------------------------------

# --- Apartment Management (CRUD) ---

@app.route('/add_apartment', methods=['GET', 'POST'])
@login_required
def add_apartment():
    conn = None # Initialize conn
    if request.method == 'POST':
        name = request.form.get('name')
        location = request.form.get('location')
        
        # 1. Basic Validation
        if not all([name, location, request.form.get('bedrooms'), request.form.get('bathrooms'), request.form.get('rent')]):
            flash("All fields are required.", "error")
            # No conn needed yet, so no close
            return render_template('add_apartment.html', form_data=request.form)

        # 2. Type/Value Validation and DB Insert
        conn = get_db_connection() 
        try:
            bedrooms = int(request.form['bedrooms'])
            bathrooms = int(request.form['bathrooms'])
            rent = float(request.form['rent'])
            
            if bedrooms <= 0 or bathrooms <= 0 or rent <= 0:
                raise ValueError("Bedrooms, Bathrooms, and Rent must be positive numbers.")

            # Insert data if validation succeeds
            conn.execute('INSERT INTO apartments (name, location, bedrooms, bathrooms, rent) VALUES (?, ?, ?, ?, ?)',
                         (name, location, bedrooms, bathrooms, rent))
            conn.commit()
            
            flash(f"Apartment '{name}' added successfully!", "success")
            return redirect(url_for('manage_apartments'))
        
        except ValueError as e:
            flash(f"Data error: {e}", "error")
            return render_template('add_apartment.html', form_data=request.form) # Return submitted data
        
        finally:
            if conn:
                conn.close()
            
    return render_template('add_apartment.html')

@app.route('/manage_apartments')
@login_required
def manage_apartments():
    conn = get_db_connection()
    # Join apartments with tenants to determine occupancy status
    apartments = conn.execute('''
        SELECT 
            a.*,
            t.fullName AS tenant_name,
            t.id AS tenant_id
        FROM 
            apartments a
        LEFT JOIN 
            tenants t ON a.id = t.apartment_id
        ORDER BY 
            a.name
    ''').fetchall()
    conn.close()
    return render_template('manage_apartments.html', apartments=apartments)

@app.route('/edit_apartment/<int:id>', methods=['GET', 'POST'])
@login_required
def edit_apartment(id):
    conn = get_db_connection()
    
    # Fetch apartment and current tenant info
    apartment = conn.execute('''
        SELECT 
            a.*, 
            t.fullName AS tenant_name, 
            t.id AS tenant_id
        FROM 
            apartments a
        LEFT JOIN 
            tenants t ON a.id = t.apartment_id
        WHERE 
            a.id = ?
    ''', (id,)).fetchone()

    if apartment is None:
        conn.close()
        flash("Apartment not found.", "error")
        return redirect(url_for('manage_apartments'))

    if request.method == 'POST':
        name = request.form['name']
        location = request.form['location']
        
        try:
            bedrooms = int(request.form['bedrooms'])
            bathrooms = int(request.form['bathrooms'])
            rent = float(request.form['rent'])
            
            if bedrooms <= 0 or bathrooms <= 0 or rent <= 0:
                raise ValueError("Bedrooms, Bathrooms, and Rent must be positive numbers.")

            conn.execute('UPDATE apartments SET name = ?, location = ?, bedrooms = ?, bathrooms = ?, rent = ? WHERE id = ?',
                         (name, location, bedrooms, bathrooms, rent, id))
            conn.commit()
            flash(f"Apartment '{name}' updated successfully!", "success")
            return redirect(url_for('manage_apartments'))

        except ValueError as e:
            # Type/Value Validation failed
            flash(f"Data error: {e}", "error")
            # Re-render with existing data and error message
            # The connection will be closed by the finally block.
            return render_template('edit_apartment.html', apartment=apartment, form_data=request.form)

        finally:
            # Connection closure is guaranteed after POST attempt
            conn.close()
            
    # GET request: Close connection after fetching data
    conn.close()
    return render_template('edit_apartment.html', apartment=apartment)

@app.route('/delete_apartment/<int:id>', methods=['POST'])
@login_required
def delete_apartment(id):
    conn = get_db_connection()
    apartment = conn.execute('SELECT name FROM apartments WHERE id = ?', (id,)).fetchone()
    
    try:
        # Deletion is safe due to ON DELETE SET NULL constraint on tenants table
        conn.execute('DELETE FROM apartments WHERE id = ?', (id,))
        conn.commit()
        
        if apartment:
            flash(f"Apartment '{apartment['name']}' deleted successfully. Any linked tenants are now unassigned.", "success")
        else:
            flash("Apartment deleted successfully.", "success")
    except Exception as e:
        flash(f"Error deleting apartment: {e}", "error")
    finally:
        conn.close()
        
    return redirect(url_for('manage_apartments'))


# ---------------- Tenant Management (CRUD) ----------------

@app.route('/add_tenant', methods=['GET', 'POST'])
@login_required
def add_tenant():
    conn = get_db_connection()
    available_apartments = get_available_apartments(conn)
    form_data_to_render = {}

    if request.method == 'POST':
        fullName = (request.form.get('fullName') or '').strip()
        phone = (request.form.get('phone') or '').strip()
        email = request.form.get('email') or None
        apartment_id_raw = request.form.get('apartment_id') or ''
        lease_start = request.form.get('lease_start') or None

        form_data_to_render = request.form
        
        # --- 1. Validation ---
        if not fullName or not phone or not lease_start:
            flash("Tenant's Full Name, Phone, and Lease Start Date are required.", "error")
            conn.close() # Close connection on validation failure
            return render_template('add_tenant.html', available_apartments=available_apartments, form_data=form_data_to_render)

        # --- 2. Apartment ID conversion ---
        apt_id_for_db = None
        if apartment_id_raw and apartment_id_raw != 'None':
            try:
                apt_id_for_db = int(apartment_id_raw)
            except ValueError:
                flash("Invalid apartment selection.", "error")
                conn.close() # Close connection on conversion error
                return render_template('add_tenant.html', available_apartments=available_apartments, form_data=form_data_to_render)

        # --- 3. Database Insert ---
        try:
            conn.execute(
                'INSERT INTO tenants (fullName, phone, email, apartment_id, lease_start) VALUES (?, ?, ?, ?, ?)',
                (fullName, phone, email, apt_id_for_db, lease_start)
            )
            conn.commit()
            flash("Tenant added successfully.", "success")
            return redirect(url_for('manage_tenants'))

        except IntegrityError:
            flash("The selected apartment is already assigned to a tenant. Please choose an available unit.", "error")
            return render_template('add_tenant.html', available_apartments=available_apartments, form_data=form_data_to_render)

        except Exception as e:
            print(f"add_tenant error: {e}")
            flash("Database error occurred while adding tenant. Check server console for details.", "error")
            return render_template('add_tenant.html', available_apartments=available_apartments, form_data=form_data_to_render)

        finally:
            # GUARANTEE connection closure for all POST outcomes (success or DB exception)
            conn.close()

    # GET request: close the connection after fetching data and before rendering
    conn.close()
    return render_template('add_tenant.html', available_apartments=available_apartments, form_data=form_data_to_render)


@app.route('/manage_tenants')
@login_required
def manage_tenants():
    """Route to view, edit, and delete all tenant records."""
    conn = get_db_connection()
    
    # Fetch all tenants, joining with the apartments table to show which unit they occupy
    tenants = conn.execute('''
        SELECT 
            t.id, 
            t.fullName, 
            t.phone, 
            t.email, 
            t.lease_start, 
            a.name AS apartment_name
        FROM 
            tenants t
        LEFT JOIN 
            apartments a ON t.apartment_id = a.id
        ORDER BY 
            t.fullName
    ''').fetchall()
    
    conn.close()
    return render_template('manage_tenants.html', tenants=tenants) 

@app.route('/edit_tenant/<int:id>', methods=['GET', 'POST'])
@login_required
def edit_tenant(id):
    conn = get_db_connection()
    tenant = conn.execute('SELECT * FROM tenants WHERE id = ?', (id,)).fetchone()

    if tenant is None:
        conn.close()
        flash("Tenant not found.", "error")
        return redirect(url_for('manage_tenants'))
    
    # 2. Get available apartments (include current tenant's unit)
    current_apt_id = tenant['apartment_id'] if tenant and tenant['apartment_id'] else -1 # Use -1 if unassigned
    available_apartments = conn.execute('''
        SELECT a.id, a.name
        FROM apartments a
        LEFT JOIN tenants t ON a.id = t.apartment_id
        WHERE t.apartment_id IS NULL OR a.id = ?
        ORDER BY a.name
    ''', (current_apt_id,)).fetchall()

    if request.method == 'POST':
        fullName = request.form.get('fullName')
        phone = request.form.get('phone')
        email = request.form.get('email')
        apartment_id = request.form.get('apartment_id')
        lease_start = request.form.get('lease_start')

        if not all([fullName, phone, lease_start]):
            flash("Tenant's Full Name, Phone, and Lease Start Date are required.", "error")
            # Connection remains open until finally block
            return redirect(url_for('edit_tenant', id=id))

        # Handle unassigned case
        apt_id_for_db = int(apartment_id) if apartment_id and apartment_id != 'None' else None

        try:
            conn.execute('UPDATE tenants SET fullName = ?, phone = ?, email = ?, apartment_id = ?, lease_start = ? WHERE id = ?',
                         (fullName, phone, email, apt_id_for_db, lease_start, id))
            conn.commit()
            flash(f"Tenant '{fullName}' updated successfully!", "success")
            return redirect(url_for('manage_tenants'))

        except IntegrityError:
            flash("The selected apartment is already assigned to a different tenant. Please choose an available unit.", "error")
            # Connection remains open until finally block
            return redirect(url_for('edit_tenant', id=id))
            
        except Exception as e:
            flash(f"An error occurred while updating the tenant: {e}", "error")
            # Connection remains open until finally block
            return redirect(url_for('edit_tenant', id=id))
            
        finally:
            # Guaranteed closure for all POST paths
            conn.close()
            
    # GET request: Close connection after fetching data
    conn.close()
    return render_template('edit_tenant.html', tenant=tenant, available_apartments=available_apartments)


@app.route('/delete_tenant/<int:id>', methods=['POST'])
@login_required
def delete_tenant(id):
    conn = get_db_connection()
    tenant = conn.execute('SELECT fullName FROM tenants WHERE id = ?', (id,)).fetchone()
    
    if tenant:
        try:
            # Deleting the tenant will cascade the deletion of associated rent_payments (ON DELETE CASCADE)
            conn.execute('DELETE FROM tenants WHERE id = ?', (id,))
            conn.commit()
            flash(f"Tenant '{tenant['fullName']}' deleted successfully. The associated apartment is now available.", "success")
        except Exception as e:
            flash(f"Error deleting tenant: {e}", "error")
        finally:
            conn.close()
    else:
        flash("Tenant not found.", "error")
        conn.close() # Close connection even if tenant is not found
        
    return redirect(url_for('manage_tenants'))

# ------------------ SPECIALIZATION ROUTE: LOG PAYMENT (FIXED) ------------------

@app.route('/log_payment/<int:tenant_id>', methods=['GET', 'POST'])
@login_required
def log_payment(tenant_id):
    conn = get_db_connection()
    # Fetch tenant and the apartment's rent
    tenant = conn.execute('''
        SELECT 
            t.*, 
            a.name AS apartment_name, 
            a.rent 
        FROM tenants t 
        LEFT JOIN apartments a ON t.apartment_id = a.id 
        WHERE t.id = ?
    ''', (tenant_id,)).fetchone()

    if not tenant:
        conn.close()
        flash("Tenant not found.", "error")
        return redirect(url_for('manage_tenants'))

    if tenant['apartment_id'] is None:
        conn.close()
        flash("Cannot log payment. This tenant is not currently assigned to an apartment.", "error")
        return redirect(url_for('manage_tenants'))

    # FIX: Initialize form_data with an empty dictionary for the GET request
    # This prevents the 'form_data is undefined' Jinja error on initial load.
    form_data = {} 

    if request.method == 'POST':
        # Store submitted data in case of validation failure
        form_data = request.form

        try:
            # 1. Validation and Type Check
            amount_paid_str = request.form.get('amount_paid')
            payment_date = request.form.get('payment_date')
            payment_for_month = request.form.get('payment_for_month')
            
            if not all([amount_paid_str, payment_date, payment_for_month]):
                flash("All payment fields are required.", "error")
                return render_template('log_payment.html', tenant=tenant, form_data=form_data)
            
            amount_paid = float(amount_paid_str)
            if amount_paid <= 0:
                raise ValueError("Amount must be a positive number.")
            
            # 2. Simple status check based on the apartment's rent
            status = 'Paid' if amount_paid >= tenant['rent'] else 'Partial'

            # 3. Database Insert
            conn.execute(
                'INSERT INTO rent_payments (tenant_id, amount_paid, payment_date, payment_for_month, status) VALUES (?, ?, ?, ?, ?)',
                (tenant_id, amount_paid, payment_date, payment_for_month, status)
            )
            conn.commit()
            
            flash(f"Payment of {amount_paid:,.2f} ETB logged for {tenant['fullName']} for {payment_for_month}.", "success")
            return redirect(url_for('manage_tenants'))

        except ValueError as e:
            flash(f"Invalid amount or date format: {e}", "error")
            # If validation fails, re-render the form with the error and submitted data
            return render_template('log_payment.html', tenant=tenant, form_data=form_data)
        
        except Exception as e:
            flash(f"A database error occurred: {e}", "error")
            return render_template('log_payment.html', tenant=tenant, form_data=form_data)
            
        finally:
            if conn:
                conn.close()
    
    # GET request (initial load): form_data is already initialized as {} above
    conn.close()
    return render_template('log_payment.html', tenant=tenant, form_data=form_data)

# ------------------------------------------------------------------------------

# ---------------- Run App ----------------
if __name__ == "__main__":
    init_db()
    print("Starting Rent in Addis Flask server...")
    app.run(debug=True)